use anyhow::{Context, Result, bail};
use serde::{Serialize, de::DeserializeOwned};
use std::{
    env,
    ffi::CStr,
    fs::{self, DirBuilder, File, OpenOptions},
    io::{Read, Write},
    os::unix::{fs::DirBuilderExt, fs::OpenOptionsExt, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::mpsc,
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tempfile::NamedTempFile;
use wait_timeout::ChildExt;

#[derive(Debug)]
pub struct CommandOutput {
    pub code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
}

pub fn now() -> Result<f64> {
    Ok(SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs_f64())
}

pub fn private_directory(path: &Path) -> Result<()> {
    DirBuilder::new().recursive(true).mode(0o700).create(path)?;
    Ok(())
}

pub fn lock_file(path: &Path) -> Result<File> {
    Ok(OpenOptions::new()
        .create(true)
        .append(true)
        .mode(0o600)
        .open(path)?)
}

pub fn read_json<T: DeserializeOwned>(path: &Path) -> Result<T> {
    let bytes = fs::read(path).with_context(|| format!("Could not read {}", path.display()))?;
    serde_json::from_slice(&bytes).with_context(|| format!("Invalid JSON in {}", path.display()))
}

pub fn write_json(path: &Path, value: &impl Serialize) -> Result<()> {
    let parent = path
        .parent()
        .context("State file has no parent directory")?;
    private_directory(parent)?;
    let mut temporary = NamedTempFile::new_in(parent)?;
    serde_json::to_writer_pretty(&mut temporary, value)?;
    temporary.write_all(b"\n")?;
    temporary.as_file().sync_all()?;
    temporary.persist(path)?;
    Ok(())
}

pub fn write_log(path: &Path, text: &str) -> Result<()> {
    let start = text
        .char_indices()
        .rev()
        .nth(16383)
        .map_or(0, |(index, _)| index);
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(path)?;
    file.write_all(&text.as_bytes()[start..])?;
    Ok(())
}

pub fn command(argv: &[String], timeout: Duration) -> Result<CommandOutput> {
    let start = Instant::now();
    let (program, args) = argv.split_first().context("Empty command")?;
    let mut child = Command::new(program)
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
        .with_context(|| format!("Could not run {program}"))?;
    let stdout = child.stdout.take().context("Missing child stdout")?;
    let stderr = child.stderr.take().context("Missing child stderr")?;
    let (done, completed) = mpsc::channel();
    let read = |mut pipe: Box<dyn Read + Send>| {
        let done = done.clone();
        thread::spawn(move || {
            let mut bytes = Vec::new();
            let result = pipe
                .read_to_end(&mut bytes)
                .map(|_| String::from_utf8_lossy(&bytes).into_owned());
            let _ = done.send(());
            result
        })
    };
    // Drain both pipes while waiting: vulnix output can exceed a pipe's capacity.
    let stdout = read(Box::new(stdout));
    let stderr = read(Box::new(stderr));
    let status = child.wait_timeout(timeout);
    // A parent can exit while a descendant still holds its output pipes open.
    let pipes_done = matches!(status, Ok(Some(_)))
        && (0..2).all(|_| {
            completed
                .recv_timeout(timeout.saturating_sub(start.elapsed()))
                .is_ok()
        });
    if !pipes_done {
        // The child owns a new process group; kill descendants holding its pipes too.
        unsafe { libc::kill(-(child.id() as libc::pid_t), libc::SIGKILL) };
        let _ = child.wait();
    }
    let stdout = stdout
        .join()
        .map_err(|_| anyhow::anyhow!("stdout reader panicked"))??;
    let stderr = stderr
        .join()
        .map_err(|_| anyhow::anyhow!("stderr reader panicked"))??;
    let status = status?.with_context(|| format!("{program} timed out after {timeout:?}"))?;
    if !pipes_done {
        bail!("{program} timed out after {timeout:?}");
    }
    Ok(CommandOutput {
        code: status.code(),
        stdout,
        stderr,
    })
}

pub fn user() -> Result<(String, PathBuf)> {
    let mut buffer = vec![0u8; 16384];
    loop {
        let mut passwd = std::mem::MaybeUninit::<libc::passwd>::uninit();
        let mut result = std::ptr::null_mut();
        // getpwuid_r stores its strings in buffer, which stays alive until copied.
        let code = unsafe {
            libc::getpwuid_r(
                libc::getuid(),
                passwd.as_mut_ptr(),
                buffer.as_mut_ptr().cast(),
                buffer.len(),
                &mut result,
            )
        };
        if code == libc::ERANGE && buffer.len() < 1024 * 1024 {
            buffer.resize(buffer.len() * 2, 0);
            continue;
        }
        if code != 0 || result.is_null() {
            bail!("Could not resolve current user (getpwuid_r: {code})");
        }
        let passwd = unsafe { passwd.assume_init() };
        let username = unsafe { CStr::from_ptr(passwd.pw_name) }
            .to_str()?
            .to_owned();
        let home = match env::var_os("HOME") {
            Some(home) => PathBuf::from(home),
            None => PathBuf::from(unsafe { CStr::from_ptr(passwd.pw_dir) }.to_str()?),
        };
        return Ok((username, home));
    }
}

pub fn expand_home(path: &str, home: &Path) -> Result<PathBuf> {
    match path {
        "~" => Ok(home.to_path_buf()),
        _ if path.starts_with("~/") => Ok(home.join(&path[2..])),
        _ if path.starts_with('~') => bail!("Use an absolute path or ~/ for runtime paths"),
        _ => Ok(PathBuf::from(path)),
    }
}
