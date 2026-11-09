use super::*;
use std::{fs, os::unix::fs::PermissionsExt, os::unix::fs::symlink, time::Instant};
use tempfile::{TempDir, tempdir};
use updates::{check_updates_with, locked_input};

const NOW: f64 = 1_793_664_000.0;
const CVE: &str = "CVE-2026-12345";

struct Fixture {
    root: TempDir,
    config: CollectConfig,
    notify: NotifyConfig,
}

impl Fixture {
    fn new() -> Self {
        let root = tempdir().unwrap();
        let state = root.path().join("state");
        private_directory(&state).unwrap();
        let config = CollectConfig {
            state_directory: state.clone(),
            extra_profiles: Vec::new(),
            known_exploited: true,
            whitelist: None,
            update_inputs: Vec::new(),
            flake_path: None,
            cvss_threshold: 7.0,
            vulnix: "vulnix".into(),
            nix: "nix".into(),
        };
        let notify = NotifyConfig {
            state_directory: state,
            notification_state: root.path().join("notifications"),
            cvss_threshold: 7.0,
            notify_send: "notify-send".into(),
        };
        Self {
            root,
            config,
            notify,
        }
    }

    fn report_path(&self) -> PathBuf {
        self.config.state_directory.join("report.json")
    }

    fn sent_path(&self) -> PathBuf {
        self.notify.notification_state.join("sent.json")
    }

    fn checkout(&mut self) -> PathBuf {
        let source = self.root.path().join("dirty checkout");
        fs::create_dir(&source).unwrap();
        write_json(&source.join("flake.lock"), &lock("old")).unwrap();
        fs::write(source.join("flake.nix"), "local uncommitted work").unwrap();
        self.config.flake_path = Some(source.to_string_lossy().into_owned());
        self.config.update_inputs = vec!["nixpkgs".into()];
        source
    }
}

fn record(score: Value) -> Value {
    json!({
        "pname": "example", "name": "example-1.0", "version": "1.0",
        "affected_by": [CVE], "cvssv3_basescore": {CVE: score}
    })
}

fn finding(score: Option<f64>) -> Finding {
    Finding {
        package: "example".into(),
        version: "1.0".into(),
        cve: CVE.into(),
        score,
        url: format!("https://nvd.nist.gov/vuln/detail/{CVE}"),
        known_exploited: false,
    }
}

fn report(findings: Vec<Finding>) -> Report {
    Report {
        generated_at: NOW,
        last_success: Some(NOW),
        findings,
        profiles: vec!["/system".into()],
        updates: Vec::new(),
        errors: Vec::new(),
    }
}

fn output(code: i32, stdout: &str, stderr: &str) -> Result<CommandOutput> {
    Ok(CommandOutput {
        code: Some(code),
        stdout: stdout.into(),
        stderr: stderr.into(),
    })
}

fn lock(revision: &str) -> Value {
    json!({
        "root": "root",
        "nodes": {
            "root": {"inputs": {"nixpkgs": "packages", "followed": ["nixpkgs"], "graphics": "graphics"}},
            "packages": {"locked": {"rev": revision}},
            "graphics": {"locked": {"rev": "pinned"}}
        }
    })
}

fn candidate(argv: &[String], value: &Value) {
    let index = argv
        .iter()
        .position(|arg| arg == "--output-lock-file")
        .unwrap();
    write_json(Path::new(&argv[index + 1]), value).unwrap();
}

#[test]
fn parses_pinned_vulnix_schema_deduplicates_and_preserves_unknown_scores() {
    let parsed = parse_findings(json!([
        record(json!(8.1)),
        record(json!(8.1)),
        record(Value::Null)
    ]))
    .unwrap();
    assert_eq!(parsed.len(), 1);
    assert_eq!(parsed[0].score, Some(8.1));
    assert_eq!(
        parse_findings(json!([record(Value::Null)])).unwrap()[0].score,
        None
    );
    assert_eq!(
        parse_findings(json!([record(Value::Null), record(json!(0))])).unwrap()[0].score,
        Some(0.0)
    );
    assert_eq!(
        parse_findings(json!([record(json!(1)), record(json!(9))])).unwrap()[0].score,
        Some(9.0)
    );
    let mut missing_scores = record(Value::Null);
    missing_scores
        .as_object_mut()
        .unwrap()
        .remove("cvssv3_basescore");
    assert_eq!(
        parse_findings(json!([missing_scores])).unwrap()[0].score,
        None
    );
    assert!(parse_findings(json!([])).unwrap().is_empty());
}

#[test]
fn malformed_scan_output_never_counts_as_clean() {
    for data in [
        json!({}),
        json!([null]),
        json!([{"affected_by": []}]),
        json!([record(json!(true))]),
        json!([record(json!(11))]),
        json!([record(json!(-1))]),
        json!([record(json!("8.1"))]),
    ] {
        assert!(parse_findings(data.clone()).is_err(), "{data}");
    }
    for field in [
        "pname",
        "name",
        "version",
        "affected_by",
        "cvssv3_basescore",
    ] {
        let mut bad = record(json!(8));
        bad[field] = Value::Null;
        assert!(parse_findings(json!([bad])).is_err(), "{field}");
    }
    for cve in [
        "CVE-2026-123",
        "CVE-26-12345",
        "CVE-2026-12345\n",
        "cve-2026-12345",
        "CVE-2026-１２３４",
    ] {
        let mut bad = record(Value::Null);
        bad["affected_by"] = json!([cve]);
        assert!(parse_findings(json!([bad])).is_err(), "{cve}");
    }
    assert!(serde_json::from_str::<Value>("[NaN]").is_err());
}

#[test]
fn findings_have_stable_package_version_cve_order() {
    let mut second = record(json!(4));
    second["pname"] = json!("aaa");
    let findings = parse_findings(json!([record(json!(8)), second])).unwrap();
    assert_eq!(findings[0].package, "aaa");
}

#[test]
fn scan_exit_status_must_agree_with_valid_findings() {
    let fixture = Fixture::new();
    for (code, stdout, stderr) in [
        (2, "[]", ""),
        (1, "[]", "offline"),
        (2, "not JSON", ""),
        (0, "[]", "Traceback (most recent call last)"),
    ] {
        assert!(
            scan_with(&fixture.config, vec!["/system".into()], |_, _| output(
                code, stdout, stderr
            ))
            .is_err()
        );
    }
    let raw = json!([record(json!(8))]).to_string();
    assert!(
        scan_with(&fixture.config, vec!["/system".into()], |_, _| output(
            0, &raw, ""
        ))
        .is_err()
    );
    assert!(!fixture.config.state_directory.join("vulnix.json").exists());
}

#[test]
fn scan_uses_runtime_closures_and_whitelist_and_retains_raw_json() {
    let mut fixture = Fixture::new();
    fixture.config.whitelist = Some("/runtime/reviewed.toml".into());
    let raw = json!([record(json!(8))]);
    let profiles = vec!["/nix/store/system".into(), "/nix/store/home".into()];
    let (findings, scanned) = scan_with(&fixture.config, profiles.clone(), |argv, timeout| {
        assert_eq!(timeout, Duration::from_secs(1800));
        assert!(argv.iter().any(|arg| arg == "--closure"));
        assert!(!argv.iter().any(|arg| arg == "--kev"));
        assert!(argv.iter().any(|arg| arg == "/runtime/reviewed.toml"));
        assert_eq!(&argv[argv.len() - 2..], profiles);
        output(2, &raw.to_string(), "diagnostics")
    })
    .unwrap();
    assert_eq!(findings.len(), 1);
    assert_eq!(scanned, profiles);
    assert_eq!(
        read_json::<Value>(&fixture.config.state_directory.join("vulnix.json")).unwrap(),
        raw
    );
    assert_eq!(
        fs::read_to_string(fixture.config.state_directory.join("vulnix.log")).unwrap(),
        "diagnostics"
    );
}

#[test]
fn dangling_optional_profiles_are_skipped_required_profiles_fail_and_symlinks_deduplicate() {
    let root = tempdir().unwrap();
    let active = root.path().join("active profile");
    fs::create_dir(&active).unwrap();
    let missing = root.path().join("missing");
    let unused = root.path().join(".nix-profile");
    symlink(&missing, &unused).unwrap();
    let alias = root.path().join("system");
    symlink(&active, &alias).unwrap();
    let profiles = resolve_profiles(vec![unused, active.clone()], BTreeSet::from([alias])).unwrap();
    assert_eq!(profiles, vec![active.to_string_lossy().into_owned()]);
    assert!(
        resolve_profiles(Vec::new(), BTreeSet::from([missing]))
            .unwrap_err()
            .to_string()
            .contains("Missing required")
    );
}

#[test]
fn failed_scan_retains_findings_profiles_and_last_success() {
    let fixture = Fixture::new();
    let mut previous = report(vec![finding(Some(8.1))]);
    previous.last_success = Some(123.0);
    write_json(&fixture.report_path(), &previous).unwrap();
    let code = collect_with(
        &fixture.config,
        NOW,
        || bail!("unavailable"),
        || Ok(BTreeSet::new()),
        || Ok(Vec::new()),
    )
    .unwrap();
    assert_eq!(code, 1);
    let retained = read_report(&fixture.report_path()).unwrap();
    assert_eq!(retained.last_success, Some(123.0));
    assert_eq!(retained.findings.len(), 1);
    assert_eq!(retained.profiles, previous.profiles);
    assert!(retained.errors[0].contains("unavailable"));
}

#[test]
fn failed_kev_refresh_preserves_cached_exploitation() {
    let fixture = Fixture::new();
    write_json(
        &fixture.config.state_directory.join("kev.json"),
        &json!({"vulnerabilities": [{"cveID": CVE}]}),
    )
    .unwrap();
    assert_eq!(
        collect_with(
            &fixture.config,
            NOW,
            || Ok((vec![finding(None)], vec!["/system".into()])),
            || bail!("offline"),
            || Ok(Vec::new())
        )
        .unwrap(),
        1
    );
    let report = read_report(&fixture.report_path()).unwrap();
    assert!(report.findings[0].known_exploited);
    assert!(is_high(&report.findings[0], 7.0));
    assert!(report.errors[0].contains("CISA"));
}

#[test]
fn corrupt_kev_cache_does_not_downgrade_previous_exploitation() {
    let fixture = Fixture::new();
    let mut exploited = finding(None);
    exploited.known_exploited = true;
    write_json(&fixture.report_path(), &report(vec![exploited])).unwrap();
    fs::write(fixture.config.state_directory.join("kev.json"), "not JSON").unwrap();
    collect_with(
        &fixture.config,
        NOW,
        || Ok((vec![finding(None)], Vec::new())),
        || bail!("offline"),
        || Ok(Vec::new()),
    )
    .unwrap();
    let retained = read_report(&fixture.report_path()).unwrap();
    assert!(retained.findings[0].known_exploited);
    assert_eq!(retained.errors.len(), 2);
}

#[test]
fn clean_empty_scan_is_success_and_disabled_kev_is_not_fetched() {
    let mut fixture = Fixture::new();
    fixture.config.known_exploited = false;
    assert_eq!(
        collect_with(
            &fixture.config,
            NOW,
            || Ok((Vec::new(), vec!["/system".into()])),
            || panic!("disabled KEV fetch"),
            || Ok(Vec::new())
        )
        .unwrap(),
        0
    );
    let clean = read_report(&fixture.report_path()).unwrap();
    assert_eq!(clean.last_success, Some(NOW));
    assert!(clean.errors.is_empty());
    assert!(clean.findings.is_empty());
}

#[test]
fn corrupt_previous_report_is_a_visible_error() {
    let fixture = Fixture::new();
    fs::write(fixture.report_path(), "[]").unwrap();
    assert_eq!(
        collect_with(
            &fixture.config,
            NOW,
            || Ok((Vec::new(), Vec::new())),
            || Ok(BTreeSet::new()),
            || Ok(Vec::new())
        )
        .unwrap(),
        1
    );
    assert!(read_report(&fixture.report_path()).unwrap().errors[0].contains("Previous report"));
}

#[test]
fn collection_lock_skips_concurrent_work() {
    let fixture = Fixture::new();
    let lock = runtime::lock_file(&fixture.config.state_directory.join("collect.lock")).unwrap();
    lock.lock().unwrap();
    assert_eq!(
        collect_with(
            &fixture.config,
            NOW,
            || panic!("scan while locked"),
            || panic!("fetch while locked"),
            || panic!("updates while locked")
        )
        .unwrap(),
        0
    );
    assert!(!fixture.report_path().exists());
}

#[test]
fn kev_rejects_stale_future_timezone_free_and_malformed_catalogs() {
    let catalog =
        json!({"dateReleased": "2026-11-01T00:00:00Z", "vulnerabilities": [{"cveID": CVE}]});
    assert_eq!(
        kev_ids(&catalog, NOW).unwrap(),
        BTreeSet::from([CVE.into()])
    );
    assert!(
        kev_ids(&catalog, NOW + 20.0 * DAY)
            .unwrap_err()
            .to_string()
            .contains("stale")
    );
    assert!(kev_ids(&catalog, NOW - 10.0 * DAY).is_err());
    for bad in [
        json!({"dateReleased": "2026-11-01T00:00:00", "vulnerabilities": [{"cveID": CVE}]}),
        json!({"dateReleased": "2026-11-01T00:00:00Z", "vulnerabilities": []}),
        json!({"dateReleased": "2026-11-01T00:00:00Z", "vulnerabilities": [{"cveID": true}]}),
        json!({"dateReleased": "2026-11-01T00:00:00Z", "vulnerabilities": [{}]}),
    ] {
        assert!(kev_ids(&bad, NOW).is_err());
    }
    assert!(
        read_kev(std::io::repeat(b' '), NOW)
            .unwrap_err()
            .to_string()
            .contains("size limit")
    );
    assert!(read_kev(&b"not JSON"[..], NOW).is_err());
}

#[test]
fn resolves_follows_and_rejects_cycles_missing_inputs_and_invalid_references() {
    assert_eq!(
        locked_input(&lock("old"), "followed").unwrap(),
        &json!({"rev": "old"})
    );
    for reference in [
        json!([]),
        json!(null),
        json!(["followed"]),
        json!(["missing"]),
        json!("missing"),
    ] {
        let mut bad = lock("old");
        bad["nodes"]["root"]["inputs"]["followed"] = reference;
        assert!(locked_input(&bad, "followed").is_err());
    }
    assert!(locked_input(&lock("old"), "typo").is_err());
}

#[test]
fn update_check_only_writes_temporary_candidate_and_preserves_pins() {
    let mut fixture = Fixture::new();
    let source = fixture.checkout();
    let original = fs::read(source.join("flake.lock")).unwrap();
    let changes = check_updates_with(&fixture.config, |argv, timeout| {
        assert_eq!(timeout, Duration::from_secs(900));
        assert!(!argv.iter().any(|arg| arg == "--accept-flake-config"));
        assert!(
            argv.windows(3)
                .any(|args| args == ["--option", "accept-flake-config", "false"])
        );
        assert!(
            argv.windows(3)
                .any(|args| args == ["--option", "allow-import-from-derivation", "false"])
        );
        assert_eq!(argv.last().unwrap(), "nixpkgs");
        let index = argv
            .iter()
            .position(|arg| arg == "--output-lock-file")
            .unwrap();
        assert!(Path::new(&argv[index + 1]).starts_with(&fixture.config.state_directory));
        candidate(argv, &lock("new"));
        output(0, "", "")
    })
    .unwrap();
    assert_eq!(changes.len(), 1);
    assert_eq!(changes[0].input, "nixpkgs");
    assert_eq!(fs::read(source.join("flake.lock")).unwrap(), original);
    assert_eq!(
        fs::read_to_string(source.join("flake.nix")).unwrap(),
        "local uncommitted work"
    );
    assert!(
        fs::read_dir(&fixture.config.state_directory)
            .unwrap()
            .all(|entry| !entry
                .unwrap()
                .file_name()
                .to_string_lossy()
                .starts_with("update-"))
    );
}

#[test]
fn unchanged_input_has_no_update_and_empty_allowlist_never_runs_nix() {
    let mut fixture = Fixture::new();
    assert!(
        check_updates_with(&fixture.config, |_, _| panic!("empty allowlist"))
            .unwrap()
            .is_empty()
    );
    fixture.checkout();
    assert!(
        check_updates_with(&fixture.config, |argv, _| {
            candidate(argv, &lock("old"));
            output(0, "", "")
        })
        .unwrap()
        .is_empty()
    );
}

#[test]
fn update_failures_and_missing_candidate_are_not_no_updates() {
    let mut fixture = Fixture::new();
    fixture.checkout();
    assert!(
        check_updates_with(&fixture.config, |_, _| output(1, "", "offline"))
            .unwrap_err()
            .to_string()
            .contains("Input check failed")
    );
    assert!(check_updates_with(&fixture.config, |_, _| output(0, "", "")).is_err());
}

#[test]
fn concurrent_source_lock_change_is_rejected() {
    let mut fixture = Fixture::new();
    let source = fixture.checkout();
    let error = check_updates_with(&fixture.config, |argv, _| {
        candidate(argv, &lock("new"));
        write_json(&source.join("flake.lock"), &lock("concurrent edit")).unwrap();
        output(0, "", "")
    })
    .unwrap_err();
    assert!(error.to_string().contains("Checkout lock changed"));
    assert_eq!(
        read_json::<Value>(&source.join("flake.lock")).unwrap(),
        lock("concurrent edit")
    );
}

#[test]
fn update_failure_retains_previous_updates() {
    let fixture = Fixture::new();
    let mut previous = report(Vec::new());
    previous.updates = serde_json::from_value(
        json!([{"input": "nixpkgs", "current": {"rev": "old"}, "available": {"rev": "new"}}]),
    )
    .unwrap();
    write_json(&fixture.report_path(), &previous).unwrap();
    collect_with(
        &fixture.config,
        NOW,
        || Ok((Vec::new(), Vec::new())),
        || Ok(BTreeSet::new()),
        || bail!("offline"),
    )
    .unwrap();
    let retained = read_report(&fixture.report_path()).unwrap();
    assert_eq!(retained.updates.len(), 1);
    assert!(retained.errors[0].contains("Update check failed"));
}

#[test]
fn missing_and_store_update_sources_are_rejected() {
    let mut fixture = Fixture::new();
    fixture.config.flake_path = Some("/nix/store/nonexistent".into());
    fixture.config.update_inputs = vec!["nixpkgs".into()];
    assert!(
        check_updates_with(&fixture.config, |_, _| panic!("store checkout"))
            .unwrap_err()
            .to_string()
            .contains("runtime checkout")
    );
    let source = fixture.checkout();
    fixture.config.update_inputs = vec!["typo".into()];
    assert!(check_updates_with(&fixture.config, |_, _| panic!("unknown input")).is_err());
    assert!(source.join("flake.lock").exists());
    fixture.config.flake_path = None;
    assert!(check_updates_with(&fixture.config, |_, _| panic!("missing source")).is_err());
}

#[test]
fn critical_normal_unknown_and_stale_classification() {
    let mut unknown = finding(None);
    unknown.cve = "CVE-2026-22222".into();
    let mut report = report(vec![finding(Some(7.0)), unknown]);
    report.updates = serde_json::from_value(
        json!([{"input": "nixpkgs", "current": {}, "available": {"rev": "new"}}]),
    )
    .unwrap();
    let groups = notification_groups(&report, 7.0, NOW);
    assert_eq!(
        groups
            .iter()
            .map(|g| (g.name, g.urgency))
            .collect::<Vec<_>>(),
        vec![
            ("advisories", "critical"),
            ("review", "normal"),
            ("updates", "normal")
        ]
    );
    let stale = notification_groups(&report, 7.0, NOW + 3.0 * DAY);
    assert_eq!(stale.last().unwrap().name, "errors");
    assert_eq!(stale.last().unwrap().lines.len(), 2);
    assert!(!is_high(&finding(None), 7.0));
    let mut exploited = finding(Some(1.0));
    exploited.known_exploited = true;
    assert!(is_high(&exploited, 7.0));
}

#[test]
fn notifications_deduplicate_remind_and_escape_markup() {
    let fixture = Fixture::new();
    let mut unsafe_name = finding(Some(8.1));
    unsafe_name.package = "<unsafe>&\"'".into();
    write_json(&fixture.report_path(), &report(vec![unsafe_name])).unwrap();
    let mut calls = Vec::new();
    let mut run = |argv: &[String], timeout| {
        assert_eq!(timeout, Duration::from_secs(30));
        calls.push(argv.to_vec());
        output(0, "", "")
    };
    notify_with(&fixture.notify, NOW, &mut run).unwrap();
    notify_with(&fixture.notify, NOW + 1.0, &mut run).unwrap();
    notify_with(&fixture.notify, NOW + DAY, &mut run).unwrap();
    assert_eq!(calls.len(), 2);
    assert!(calls[0].iter().any(|arg| arg == "--urgency=critical"));
    assert!(calls[0].iter().any(|arg| arg == "--expire-time=0"));
    assert!(
        calls[0]
            .last()
            .unwrap()
            .contains("&lt;unsafe&gt;&amp;&quot;&#x27;")
    );
}

#[test]
fn failed_delivery_retries_without_acknowledging() {
    let fixture = Fixture::new();
    write_json(&fixture.report_path(), &report(vec![finding(Some(8.1))])).unwrap();
    assert!(notify_with(&fixture.notify, NOW, |_, _| output(1, "", "no bus")).is_err());
    assert!(!fixture.sent_path().exists());
    let mut calls = 0;
    notify_with(&fixture.notify, NOW + 1.0, |_, _| {
        calls += 1;
        output(0, "", "")
    })
    .unwrap();
    assert_eq!(calls, 1);
}

#[test]
fn resolved_findings_are_forgotten_so_recurrence_alerts() {
    let fixture = Fixture::new();
    let mut calls = 0;
    for (offset, findings) in [
        (0.0, vec![finding(Some(8.1))]),
        (1.0, Vec::new()),
        (2.0, vec![finding(Some(8.1))]),
    ] {
        write_json(&fixture.report_path(), &report(findings)).unwrap();
        notify_with(&fixture.notify, NOW + offset, |_, _| {
            calls += 1;
            output(0, "", "")
        })
        .unwrap();
    }
    assert_eq!(calls, 2);
}

#[test]
fn missing_corrupt_and_unreadable_reports_are_visible_normal_warnings() {
    for data in [
        None,
        Some("not JSON"),
        Some("[]"),
        Some("{}"),
        Some("{\"findings\":[]}"),
    ] {
        let fixture = Fixture::new();
        if let Some(data) = data {
            fs::write(fixture.report_path(), data).unwrap();
        }
        let mut calls = Vec::new();
        notify_with(&fixture.notify, NOW, |argv, _| {
            calls.push(argv.to_vec());
            output(0, "", "")
        })
        .unwrap();
        assert_eq!(calls.len(), 1);
        assert!(calls[0].iter().any(|arg| arg == "--urgency=normal"));
        assert!(
            calls[0]
                .last()
                .unwrap()
                .contains("Security report unavailable")
        );
    }
    let fixture = Fixture::new();
    fs::create_dir(fixture.report_path()).unwrap();
    notify_with(&fixture.notify, NOW, |argv, _| {
        assert!(argv.last().unwrap().contains("Security report unavailable"));
        output(0, "", "")
    })
    .unwrap();
}

#[test]
fn malformed_notification_state_is_replaced_and_changed_payload_alerts() {
    let fixture = Fixture::new();
    write_json(&fixture.report_path(), &report(vec![finding(Some(8.1))])).unwrap();
    private_directory(&fixture.notify.notification_state).unwrap();
    fs::write(fixture.sent_path(), "[]").unwrap();
    let mut calls = 0;
    notify_with(&fixture.notify, NOW, |_, _| {
        calls += 1;
        output(0, "", "")
    })
    .unwrap();
    write_json(&fixture.report_path(), &report(vec![finding(Some(9.0))])).unwrap();
    notify_with(&fixture.notify, NOW + 1.0, |_, _| {
        calls += 1;
        output(0, "", "")
    })
    .unwrap();
    assert_eq!(calls, 2);
}

#[test]
fn reads_existing_python_report_and_sent_schema() {
    let fixture = Fixture::new();
    write_json(
        &fixture.report_path(),
        &json!({
            "generated_at": NOW, "last_success": NOW, "profiles": ["/system"],
            "findings": [{"package": "example", "version": "1.0", "cve": CVE, "score": null,
                "url": format!("https://nvd.nist.gov/vuln/detail/{CVE}"), "known_exploited": true}],
            "updates": [], "errors": []
        }),
    )
    .unwrap();
    private_directory(&fixture.notify.notification_state).unwrap();
    write_json(
        &fixture.sent_path(),
        &json!({"advisories": {"fingerprint": "old-python-hash", "time": NOW}}),
    )
    .unwrap();
    notify_with(&fixture.notify, NOW, |argv, _| {
        assert!(
            argv.last()
                .unwrap()
                .contains("CVSS unknown; known exploited")
        );
        output(0, "", "")
    })
    .unwrap();
}

#[test]
fn state_is_atomic_private_and_logs_are_bounded_without_splitting_unicode() {
    let root = tempdir().unwrap();
    let path = root.path().join("private/report.json");
    write_json(&path, &json!({"old": true})).unwrap();
    write_json(&path, &json!({"new": true})).unwrap();
    assert_eq!(read_json::<Value>(&path).unwrap(), json!({"new": true}));
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o600
    );
    assert_eq!(
        fs::metadata(path.parent().unwrap())
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o700
    );
    assert_eq!(fs::read_dir(path.parent().unwrap()).unwrap().count(), 1);
    let log = root.path().join("log");
    runtime::write_log(&log, &"🦀".repeat(20000)).unwrap();
    assert_eq!(fs::read_to_string(log).unwrap().chars().count(), 16384);
}

#[test]
fn command_drains_both_pipes_and_checks_exit_status() {
    let argv = vec!["sh".into(), "-c".into(), "i=0; while [ \"$i\" -lt 6000 ]; do printf 'stdoutxxxxxxxxxxxxxxxxxxxxxx\\n'; printf 'stderrxxxxxxxxxxxxxxxxxxxxxx\\n' >&2; i=$((i+1)); done; exit 2".into()];
    let result = runtime::command(&argv, Duration::from_secs(30)).unwrap();
    assert_eq!(result.code, Some(2));
    assert_eq!(result.stdout.lines().count(), 6000);
    assert_eq!(result.stderr.lines().count(), 6000);
}

#[test]
fn command_times_out_and_kills_descendants_holding_pipes() {
    let start = Instant::now();
    let result = runtime::command(
        &["sh".into(), "-c".into(), "sleep 30 & wait".into()],
        Duration::from_millis(100),
    );
    assert!(result.unwrap_err().to_string().contains("timed out"));
    assert!(start.elapsed() < Duration::from_secs(10));
    assert!(runtime::command(&["/nonexistent/command".into()], Duration::from_secs(1)).is_err());
}

#[test]
fn command_timeout_also_covers_pipes_after_parent_exits() {
    let start = Instant::now();
    let error = runtime::command(
        &["sh".into(), "-c".into(), "sleep 30 & exit 0".into()],
        Duration::from_millis(100),
    )
    .unwrap_err();
    assert!(error.to_string().contains("timed out"));
    assert!(start.elapsed() < Duration::from_secs(10));
}

#[test]
fn successful_groups_are_acknowledged_even_if_a_later_group_fails() {
    let fixture = Fixture::new();
    let mut mixed = report(vec![finding(Some(8.1)), finding(None)]);
    mixed.errors.push("offline".into());
    write_json(&fixture.report_path(), &mixed).unwrap();
    let mut calls = 0;
    assert!(
        notify_with(&fixture.notify, NOW, |_, _| {
            calls += 1;
            output(if calls == 1 { 0 } else { 1 }, "", "")
        })
        .is_err()
    );
    let sent: BTreeMap<String, Sent> = read_json(&fixture.sent_path()).unwrap();
    assert!(sent.contains_key("advisories"));
    assert!(!sent.contains_key("review"));
    let mut remaining = Vec::new();
    notify_with(&fixture.notify, NOW + 1.0, |argv, _| {
        remaining.push(argv.to_vec());
        output(0, "", "")
    })
    .unwrap();
    assert_eq!(remaining.len(), 2);
    assert!(
        remaining
            .iter()
            .all(|argv| !argv.iter().any(|arg| arg == "--urgency=critical"))
    );
}
