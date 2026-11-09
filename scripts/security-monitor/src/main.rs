use anyhow::{Context, Result, bail};
use dashnix_security_monitor::{CollectConfig, NotifyConfig, collect, notify, runtime};
use std::{env, path::PathBuf, process::ExitCode};

const USAGE: &str = "Usage: dashnix-security-monitor <collect|notify> --config <path>\n\nUnprivileged advisory collection and graphical-session report delivery.";

fn run() -> Result<i32> {
    let args: Vec<_> = env::args_os().skip(1).collect();
    if args.iter().any(|arg| arg == "--help" || arg == "-h") {
        println!("{USAGE}");
        return Ok(0);
    }
    let mut args = args.into_iter();
    let mut mode = None;
    let mut path = None;
    while let Some(arg) = args.next() {
        if arg == "--config" {
            path = Some(PathBuf::from(args.next().context(USAGE)?));
        } else if let Some(value) = arg.to_str().and_then(|arg| arg.strip_prefix("--config=")) {
            path = Some(PathBuf::from(value));
        } else if (arg == "collect" || arg == "notify") && mode.is_none() {
            mode = Some(arg);
        } else {
            bail!("{USAGE}");
        }
    }
    let mode = mode.context(USAGE)?;
    let path = path.context(USAGE)?;
    // All runtime files are private, including files created by child processes.
    unsafe { libc::umask(0o077) };
    let now = runtime::now()?;
    match mode.to_str() {
        Some("collect") => {
            let config: CollectConfig = runtime::read_json(&path)?;
            collect(&config, now)
        }
        Some("notify") => {
            let config: NotifyConfig = runtime::read_json(&path)?;
            notify(&config, now)
        }
        _ => bail!("{USAGE}"),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => ExitCode::from(code as u8),
        Err(error) => {
            eprintln!("DashNix: {error:#}");
            ExitCode::FAILURE
        }
    }
}
