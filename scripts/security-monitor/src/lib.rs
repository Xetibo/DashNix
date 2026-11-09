pub mod runtime;
mod updates;

use anyhow::{Context, Result, bail, ensure};
use runtime::{CommandOutput, private_directory, read_json, write_json};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::TryLockError,
    io::Read,
    path::{Path, PathBuf},
    time::Duration,
};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};

const DAY: f64 = 86400.0;
const KEV_URL: &str =
    "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json";
const KEV_LIMIT: u64 = 16 * 1024 * 1024;

#[derive(Debug, Deserialize)]
pub struct CollectConfig {
    pub state_directory: PathBuf,
    pub extra_profiles: Vec<String>,
    pub known_exploited: bool,
    pub whitelist: Option<String>,
    pub update_inputs: Vec<String>,
    pub flake_path: Option<String>,
    pub cvss_threshold: f64,
    pub vulnix: String,
    pub nix: String,
}

#[derive(Debug, Deserialize)]
pub struct NotifyConfig {
    pub state_directory: PathBuf,
    pub notification_state: PathBuf,
    pub cvss_threshold: f64,
    pub notify_send: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct Finding {
    package: String,
    version: String,
    cve: String,
    score: Option<f64>,
    #[serde(default)]
    url: String,
    #[serde(default)]
    known_exploited: bool,
}

#[derive(Debug, Deserialize, Serialize)]
struct Report {
    generated_at: f64,
    last_success: Option<f64>,
    findings: Vec<Finding>,
    #[serde(default)]
    profiles: Vec<String>,
    updates: Vec<updates::Update>,
    errors: Vec<String>,
}

#[derive(Deserialize)]
struct VulnixRecord {
    pname: String,
    version: String,
    #[serde(rename = "name")]
    _name: String,
    affected_by: Vec<String>,
    #[serde(default)]
    cvssv3_basescore: BTreeMap<String, Value>,
}

fn valid_cve(cve: &str) -> bool {
    cve.strip_prefix("CVE-")
        .and_then(|id| id.split_once('-'))
        .is_some_and(|(year, id)| {
            year.len() == 4
                && id.len() >= 4
                && year.bytes().chain(id.bytes()).all(|c| c.is_ascii_digit())
        })
}

fn valid_score(score: f64) -> bool {
    score.is_finite() && (0.0..=10.0).contains(&score)
}

fn parse_findings(records: Value) -> Result<Vec<Finding>> {
    let records: Vec<VulnixRecord> =
        serde_json::from_value(records).context("Invalid vulnix package/CVE fields")?;
    let mut findings = BTreeMap::<(String, String, String), Finding>::new();
    for record in records {
        for cve in record.affected_by {
            ensure!(valid_cve(&cve), "Invalid CVE identifier");
            let score = match record.cvssv3_basescore.get(&cve) {
                None | Some(Value::Null) => None,
                Some(value) => {
                    let score = value.as_f64().context("Invalid CVSS score")?;
                    ensure!(valid_score(score), "Invalid CVSS score");
                    Some(score)
                }
            };
            let key = (record.pname.clone(), record.version.clone(), cve.clone());
            let finding = Finding {
                package: record.pname.clone(),
                version: record.version.clone(),
                url: format!("https://nvd.nist.gov/vuln/detail/{cve}"),
                cve,
                score,
                known_exploited: false,
            };
            let entry = findings.entry(key).or_insert_with(|| finding.clone());
            if score > entry.score {
                *entry = finding;
            }
        }
    }
    Ok(findings.into_values().collect())
}

fn resolve_profiles(candidates: Vec<PathBuf>, required: BTreeSet<PathBuf>) -> Result<Vec<String>> {
    let mut profiles = BTreeSet::new();
    for path in candidates.iter().chain(required.iter()) {
        if path.exists() {
            profiles.insert(path.canonicalize()?.to_string_lossy().into_owned());
        } else if required.contains(path) {
            bail!("Missing required runtime profile: {}", path.display());
        }
    }
    Ok(profiles.into_iter().collect())
}

fn scan_profiles(extras: &[String]) -> Result<Vec<String>> {
    let (username, home) = runtime::user()?;
    let candidates = vec![
        "/run/current-system".into(),
        "/run/booted-system".into(),
        "/nix/var/nix/profiles/system".into(),
        home.join(".nix-profile"),
        home.join(".local/state/nix/profiles/profile"),
        home.join(".local/state/nix/profiles/home-manager"),
        PathBuf::from("/nix/var/nix/profiles/per-user")
            .join(&username)
            .join("home-manager"),
        PathBuf::from("/etc/profiles/per-user").join(&username),
    ];
    let mut required = BTreeSet::from([PathBuf::from("/run/current-system")]);
    for path in extras {
        required.insert(runtime::expand_home(path, &home)?);
    }
    resolve_profiles(candidates, required)
}

fn scan_with(
    config: &CollectConfig,
    profiles: Vec<String>,
    run: impl FnOnce(&[String], Duration) -> Result<CommandOutput>,
) -> Result<(Vec<Finding>, Vec<String>)> {
    let state = &config.state_directory;
    let mut argv = vec![
        config.vulnix.clone(),
        "--closure".into(),
        "--json".into(),
        "--cache-dir".into(),
        state.join("cache/vulnix").to_string_lossy().into_owned(),
    ];
    if let Some(whitelist) = &config.whitelist {
        argv.extend(["--whitelist".into(), whitelist.clone()]);
    }
    argv.extend(profiles.clone());
    let result = run(&argv, Duration::from_secs(1800))?;
    runtime::write_log(&state.join("vulnix.log"), &result.stderr)?;
    ensure!(
        matches!(result.code, Some(0 | 2))
            && !result.stderr.contains("Traceback (most recent call last)"),
        "vulnix failed (exit {:?}); see {}/vulnix.log",
        result.code,
        state.display()
    );
    let raw: Value = serde_json::from_str(&result.stdout)?;
    let findings = parse_findings(raw.clone())?;
    // vulnix also returns 2 on runtime errors, not only on findings.
    ensure!(
        (result.code == Some(2)) != findings.is_empty(),
        "vulnix exit status disagrees with its findings"
    );
    write_json(&state.join("vulnix.json"), &raw)?;
    Ok((findings, profiles))
}

fn catalog_ids(catalog: &Value) -> Result<BTreeSet<String>> {
    let entries = catalog["vulnerabilities"]
        .as_array()
        .context("CISA catalog is empty or invalid")?;
    ensure!(!entries.is_empty(), "CISA catalog is empty or invalid");
    entries
        .iter()
        .map(|entry| {
            let cve = entry["cveID"]
                .as_str()
                .context("Invalid CVE in CISA catalog")?;
            ensure!(valid_cve(cve), "Invalid CVE in CISA catalog");
            Ok(cve.to_owned())
        })
        .collect()
}

fn kev_ids(catalog: &Value, now: f64) -> Result<BTreeSet<String>> {
    let released = OffsetDateTime::parse(
        catalog["dateReleased"]
            .as_str()
            .context("Missing CISA release date")?,
        &Rfc3339,
    )?;
    let age = now - released.unix_timestamp() as f64;
    ensure!(
        (-DAY..=14.0 * DAY).contains(&age),
        "CISA catalog is stale or has a future release date"
    );
    catalog_ids(catalog)
}

fn fetch_kev(state: &Path, now: f64) -> Result<BTreeSet<String>> {
    let response = ureq::AgentBuilder::new()
        .try_proxy_from_env(true)
        .timeout(Duration::from_secs(60))
        .build()
        .get(KEV_URL)
        .call()?;
    let (catalog, ids) = read_kev(response.into_reader(), now)?;
    write_json(&state.join("kev.json"), &catalog)?;
    Ok(ids)
}

fn read_kev(reader: impl Read, now: f64) -> Result<(Value, BTreeSet<String>)> {
    let mut bytes = Vec::new();
    reader.take(KEV_LIMIT + 1).read_to_end(&mut bytes)?;
    ensure!(
        bytes.len() as u64 <= KEV_LIMIT,
        "CISA catalog exceeded size limit"
    );
    let catalog = serde_json::from_slice(&bytes)?;
    let ids = kev_ids(&catalog, now)?;
    Ok((catalog, ids))
}

fn read_report(path: &Path) -> Result<Report> {
    let report: Report = read_json(path)?;
    ensure!(
        report
            .findings
            .iter()
            .all(|f| f.score.is_none_or(valid_score)),
        "Invalid CVSS score in report"
    );
    Ok(report)
}

pub fn collect(config: &CollectConfig, now: f64) -> Result<i32> {
    collect_with(
        config,
        now,
        || {
            scan_with(
                config,
                scan_profiles(&config.extra_profiles)?,
                runtime::command,
            )
        },
        || fetch_kev(&config.state_directory, now),
        || updates::check_updates_with(config, runtime::command),
    )
}

fn collect_with(
    config: &CollectConfig,
    now: f64,
    scan: impl FnOnce() -> Result<(Vec<Finding>, Vec<String>)>,
    fetch: impl FnOnce() -> Result<BTreeSet<String>>,
    updates: impl FnOnce() -> Result<Vec<updates::Update>>,
) -> Result<i32> {
    ensure!(valid_score(config.cvss_threshold), "Invalid CVSS threshold");
    let state = &config.state_directory;
    private_directory(state)?;
    let lock = runtime::lock_file(&state.join("collect.lock"))?;
    match lock.try_lock() {
        Ok(()) => (),
        Err(TryLockError::WouldBlock) => return Ok(0),
        Err(TryLockError::Error(error)) => return Err(error.into()),
    }
    let mut errors = Vec::new();
    let previous = if state.join("report.json").exists() {
        match read_report(&state.join("report.json")) {
            Ok(report) => Some(report),
            Err(error) => {
                errors.push(format!("Previous report could not be read: {error:#}"));
                None
            }
        }
    } else {
        None
    };
    let previous_known: BTreeSet<_> = previous
        .iter()
        .flat_map(|report| &report.findings)
        .filter(|finding| finding.known_exploited)
        .map(|finding| finding.cve.clone())
        .collect();
    let mut report = previous.unwrap_or(Report {
        generated_at: now,
        last_success: None,
        findings: Vec::new(),
        profiles: Vec::new(),
        updates: Vec::new(),
        errors: Vec::new(),
    });
    report.generated_at = now;
    report.errors = errors;
    match scan() {
        Ok((findings, profiles)) => {
            report.findings = findings;
            report.profiles = profiles;
            report.last_success = Some(now);
        }
        Err(error) => report
            .errors
            .push(format!("Advisory scan failed: {error:#}")),
    }
    let mut known = BTreeSet::new();
    if config.known_exploited {
        match fetch() {
            Ok(ids) => known = ids,
            Err(error) => {
                report
                    .errors
                    .push(format!("CISA catalog check failed: {error:#}"));
                known = previous_known;
                let cached = state.join("kev.json");
                if cached.exists() {
                    match read_json(&cached).and_then(|catalog| catalog_ids(&catalog)) {
                        Ok(ids) => known.extend(ids),
                        Err(error) => report
                            .errors
                            .push(format!("Cached CISA catalog could not be read: {error:#}")),
                    }
                }
            }
        }
    }
    for finding in &mut report.findings {
        finding.known_exploited = known.contains(&finding.cve);
    }
    match updates() {
        Ok(updates) => report.updates = updates,
        Err(error) => report
            .errors
            .push(format!("Update check failed: {error:#}")),
    }
    write_json(&state.join("report.json"), &report)?;
    let high = report
        .findings
        .iter()
        .filter(|f| is_high(f, config.cvss_threshold))
        .count();
    println!(
        "DashNix: {} possible package/CVE matches, {high} high-risk; {} input updates; {} check errors. Report: {}/report.json",
        report.findings.len(),
        report.updates.len(),
        report.errors.len(),
        state.display()
    );
    for error in &report.errors {
        println!("{error}");
    }
    Ok(i32::from(!report.errors.is_empty()))
}

fn is_high(finding: &Finding, threshold: f64) -> bool {
    finding.known_exploited || finding.score.is_some_and(|score| score >= threshold)
}

struct Notification {
    name: &'static str,
    urgency: &'static str,
    title: &'static str,
    payload: Value,
    lines: Vec<String>,
}

fn notification_groups(report: &Report, threshold: f64, now: f64) -> Vec<Notification> {
    let (high, other): (Vec<_>, Vec<_>) = report
        .findings
        .iter()
        .partition(|finding| is_high(finding, threshold));
    let mut groups = Vec::new();
    if !high.is_empty() {
        let mut lines: Vec<_> = high
            .iter()
            .take(5)
            .map(|f| {
                format!(
                    "{} {}: {} (CVSS {}{})",
                    f.package,
                    f.version,
                    f.cve,
                    f.score
                        .map_or_else(|| "unknown".into(), |score| score.to_string()),
                    if f.known_exploited {
                        "; known exploited"
                    } else {
                        ""
                    }
                )
            })
            .collect();
        lines.push("Possible matches: verify backports and exposure before remediation.".into());
        groups.push(Notification {
            name: "advisories",
            urgency: "critical",
            title: "High-risk package advisories",
            payload: json!(high),
            lines,
        });
    }
    if !other.is_empty() {
        groups.push(Notification {
            name: "review", urgency: "normal", title: "Package advisories need review",
            payload: json!(other),
            lines: vec![format!("{} lower/unknown-severity package/CVE matches. Unknown scores are not safe scores.", other.len())],
        });
    }
    if !report.updates.is_empty() {
        groups.push(Notification {
            name: "updates", urgency: "normal", title: "Tracked flake inputs have updates",
            payload: json!(report.updates),
            lines: vec![
                report.updates.iter().map(|change| change.input.as_str()).collect::<Vec<_>>().join(", "),
                "Input revisions changed; not proof every installed package has an update. No changes applied.".into(),
            ],
        });
    }
    let mut errors = report.errors.clone();
    if report
        .last_success
        .is_none_or(|last| now - last > 2.0 * DAY)
    {
        errors.push(
            "No successful advisory scan within 48 hours; retained findings may be stale.".into(),
        );
    }
    if now - report.generated_at > 2.0 * DAY {
        errors
            .push("Security report is older than 48 hours; check the system timer/service.".into());
    }
    if !errors.is_empty() {
        groups.push(Notification {
            name: "errors",
            urgency: "normal",
            title: "Security checks need attention",
            payload: json!(errors),
            lines: errors.into_iter().take(5).collect(),
        });
    }
    groups
}

fn escape_markup(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#x27;")
}

#[derive(Deserialize, Serialize)]
struct Sent {
    fingerprint: String,
    time: f64,
}

pub fn notify(config: &NotifyConfig, now: f64) -> Result<i32> {
    notify_with(config, now, runtime::command)
}

fn notify_with(
    config: &NotifyConfig,
    now: f64,
    mut run: impl FnMut(&[String], Duration) -> Result<CommandOutput>,
) -> Result<i32> {
    ensure!(valid_score(config.cvss_threshold), "Invalid CVSS threshold");
    let report_path = config.state_directory.join("report.json");
    let report = read_report(&report_path).unwrap_or_else(|error| Report {
        generated_at: 0.0,
        last_success: None,
        findings: Vec::new(),
        profiles: Vec::new(),
        updates: Vec::new(),
        errors: vec![format!("Security report unavailable: {error:#}")],
    });
    let groups = notification_groups(&report, config.cvss_threshold, now);
    let state = &config.notification_state;
    private_directory(state)?;
    let lock = runtime::lock_file(&state.join("notify.lock"))?;
    lock.lock()?;
    let mut sent: BTreeMap<String, Sent> = read_json(&state.join("sent.json")).unwrap_or_default();
    let mut active = BTreeSet::new();
    for group in groups {
        active.insert(group.name.to_owned());
        let fingerprint = format!("{:x}", Sha256::digest(serde_json::to_vec(&group.payload)?));
        if sent
            .get(group.name)
            .is_some_and(|old| old.fingerprint == fingerprint && now - old.time < DAY)
        {
            continue;
        }
        let mut lines = group.lines;
        lines.push(format!("Report: {}", report_path.display()));
        let body = lines
            .iter()
            .map(|line| escape_markup(line))
            .collect::<Vec<_>>()
            .join("\n");
        let mut argv = vec![
            config.notify_send.clone(),
            "--app-name=DashNix".into(),
            format!("--urgency={}", group.urgency),
        ];
        if group.urgency == "critical" {
            argv.push("--expire-time=0".into());
        }
        argv.extend([group.title.into(), body]);
        let result = run(&argv, Duration::from_secs(30))?;
        ensure!(
            result.code == Some(0),
            "Desktop notification failed; report will be retried"
        );
        sent.insert(
            group.name.into(),
            Sent {
                fingerprint,
                time: now,
            },
        );
        write_json(&state.join("sent.json"), &sent)?;
    }
    sent.retain(|name, _| active.contains(name));
    write_json(&state.join("sent.json"), &sent)?;
    Ok(0)
}

#[cfg(test)]
mod tests;
