use serde_json::json;
use std::{fs, process::Command};
use tempfile::tempdir;

const BIN: &str = env!("CARGO_BIN_EXE_dashnix-security-monitor");

#[test]
fn help_and_invalid_arguments() {
    let help = Command::new(BIN).arg("--help").output().unwrap();
    assert!(help.status.success());
    assert!(String::from_utf8_lossy(&help.stdout).contains("<collect|notify> --config <path>"));
    for args in [
        vec![],
        vec!["collect"],
        vec!["invalid", "--config", "/nonexistent"],
    ] {
        assert!(
            !Command::new(BIN)
                .args(args)
                .output()
                .unwrap()
                .status
                .success()
        );
    }
}

#[test]
fn notification_only_config_reports_missing_report_and_retries_failed_delivery() {
    let root = tempdir().unwrap();
    let config = root.path().join("notify.json");
    let state = root.path().join("notifications");
    let settings = |program| {
        json!({
            "state_directory": root.path().join("missing report"),
            "notification_state": state,
            "cvss_threshold": 7,
            "notify_send": program
        })
        .to_string()
    };
    fs::write(&config, settings("false")).unwrap();
    let failed = Command::new(BIN)
        .args(["notify", "--config"])
        .arg(&config)
        .output()
        .unwrap();
    assert!(!failed.status.success());
    assert!(String::from_utf8_lossy(&failed.stderr).contains("report will be retried"));
    assert!(!state.join("sent.json").exists());
    fs::write(&config, settings("true")).unwrap();
    assert!(
        Command::new(BIN)
            .args(["notify", "--config"])
            .arg(&config)
            .output()
            .unwrap()
            .status
            .success()
    );
    let sent: serde_json::Value =
        serde_json::from_slice(&fs::read(state.join("sent.json")).unwrap()).unwrap();
    assert!(sent["errors"]["fingerprint"].is_string());
    for args in [
        vec![
            "--config".into(),
            config.to_string_lossy().into_owned(),
            "notify".into(),
        ],
        vec!["notify".into(), format!("--config={}", config.display())],
    ] {
        assert!(
            Command::new(BIN)
                .args(args)
                .output()
                .unwrap()
                .status
                .success()
        );
    }
}

#[test]
fn collection_failure_writes_report_without_notify_settings() {
    let root = tempdir().unwrap();
    let config = root.path().join("collect.json");
    let state = root.path().join("state");
    fs::write(
        &config,
        json!({
            "state_directory": state, "extra_profiles": [], "known_exploited": false,
            "whitelist": null, "update_inputs": [], "flake_path": null,
            "cvss_threshold": 7, "vulnix": "/nonexistent/vulnix", "nix": "/nonexistent/nix"
        })
        .to_string(),
    )
    .unwrap();
    let output = Command::new(BIN)
        .args(["collect", "--config"])
        .arg(config)
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let report: serde_json::Value =
        serde_json::from_slice(&fs::read(state.join("report.json")).unwrap()).unwrap();
    assert!(report["last_success"].is_null());
    assert!(
        report["errors"][0]
            .as_str()
            .unwrap()
            .contains("Advisory scan failed")
    );
}
