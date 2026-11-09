use crate::{CollectConfig, runtime};
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{collections::BTreeSet, fs, time::Duration};

#[derive(Debug, Deserialize, Serialize)]
pub(crate) struct Update {
    pub input: String,
    current: Value,
    available: Value,
}

fn root(lock: &Value) -> Result<&Value> {
    let name = lock["root"].as_str().context("Invalid flake lock root")?;
    lock["nodes"]
        .get(name)
        .context("Missing flake lock root node")
}

fn resolve<'a>(lock: &'a Value, reference: &Value, seen: &BTreeSet<String>) -> Result<&'a Value> {
    let marker = serde_json::to_string(reference)?;
    ensure!(!seen.contains(&marker), "Cyclic flake input follows");
    let mut seen = seen.clone();
    seen.insert(marker);
    if let Some(name) = reference.as_str() {
        return lock["nodes"].get(name).context("Missing flake input node");
    }
    let parts = reference
        .as_array()
        .context("Invalid flake input reference")?;
    ensure!(!parts.is_empty(), "Invalid flake input reference");
    let mut node = root(lock)?;
    for part in parts {
        let part = part.as_str().context("Invalid flake follows path")?;
        let reference = node["inputs"]
            .get(part)
            .context("Missing followed flake input")?;
        node = resolve(lock, reference, &seen)?;
    }
    Ok(node)
}

pub(crate) fn locked_input<'a>(lock: &'a Value, name: &str) -> Result<&'a Value> {
    let reference = root(lock)?["inputs"]
        .get(name)
        .context("Missing selected flake input")?;
    let locked = resolve(lock, reference, &BTreeSet::new())?
        .get("locked")
        .context("Selected flake input is not locked")?;
    ensure!(locked.is_object(), "Invalid locked flake input");
    Ok(locked)
}

pub(crate) fn check_updates_with(
    config: &CollectConfig,
    run: impl FnOnce(&[String], Duration) -> Result<runtime::CommandOutput>,
) -> Result<Vec<Update>> {
    if config.update_inputs.is_empty() {
        return Ok(Vec::new());
    }
    let (_, home) = runtime::user()?;
    let source = runtime::expand_home(
        config
            .flake_path
            .as_deref()
            .context("Update checks require a runtime checkout")?,
        &home,
    )?;
    ensure!(
        !source.starts_with("/nix/store"),
        "Update checks require a runtime checkout, not /nix/store"
    );
    let source = source.canonicalize()?;
    ensure!(
        !source.starts_with("/nix/store"),
        "Update checks require a runtime checkout, not /nix/store"
    );
    let lock_path = source.join("flake.lock");
    let before = fs::read(&lock_path)?;
    let old = serde_json::from_slice(&before)?;
    for name in &config.update_inputs {
        locked_input(&old, name)?;
    }
    let temporary = tempfile::Builder::new()
        .prefix("update-")
        .tempdir_in(&config.state_directory)?;
    let candidate = temporary.path().join("flake.lock");
    let mut argv = vec![
        config.nix.clone(),
        "--extra-experimental-features".into(),
        "nix-command flakes".into(),
        "--option".into(),
        "accept-flake-config".into(),
        "false".into(),
        "--option".into(),
        "allow-import-from-derivation".into(),
        "false".into(),
        "flake".into(),
        "update".into(),
        "--flake".into(),
        source.to_string_lossy().into_owned(),
        "--output-lock-file".into(),
        candidate.to_string_lossy().into_owned(),
    ];
    argv.extend(config.update_inputs.clone());
    let result = run(&argv, Duration::from_secs(900))?;
    runtime::write_log(&config.state_directory.join("updates.log"), &result.stderr)?;
    ensure!(
        fs::read(&lock_path)? == before,
        "Checkout lock changed during update check; retry after editing/rebuilding"
    );
    ensure!(
        result.code == Some(0),
        "Input check failed (exit {:?}); see {}/updates.log",
        result.code,
        config.state_directory.display()
    );
    let new: Value = runtime::read_json(&candidate)
        .context("Nix did not produce a valid candidate lock file")?;
    let mut changes = Vec::new();
    for name in &config.update_inputs {
        let current = locked_input(&old, name)?;
        let available = locked_input(&new, name)?;
        if current != available {
            changes.push(Update {
                input: name.clone(),
                current: current.clone(),
                available: available.clone(),
            });
        }
    }
    Ok(changes)
}
