//! Downloads a release zip, checks its SHA-256 and unpacks it into `versions/<version>/`,
//! complete or not at all. Keeps the newest few version folders. Same rules as the game's
//! old `VersionInstaller`.

use crate::feed::{Release, USER_AGENT};
use crate::version;
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// Version folders kept after an install.
pub const KEEP: usize = 2;
const CHUNK: usize = 64 * 1024;

/// The game exe inside each version folder.
pub fn game_exe_name() -> &'static str {
    if cfg!(windows) {
        "ExperimentUndead.exe"
    } else {
        "ExperimentUndead.x86_64"
    }
}

pub struct Installer {
    /// Folder that holds one folder per installed version.
    pub versions_dir: PathBuf,
}

impl Installer {
    pub fn new(versions_dir: PathBuf) -> Self {
        Self { versions_dir }
    }

    /// Complete version folders (a `.tmp` folder is a failed install), newest first.
    pub fn installed(&self) -> Vec<String> {
        let Ok(entries) = fs::read_dir(&self.versions_dir) else {
            return Vec::new();
        };
        let mut found: Vec<String> = entries
            .filter_map(Result::ok)
            .filter(|entry| entry.path().is_dir())
            .filter_map(|entry| entry.file_name().into_string().ok())
            .filter(|name| version::is_release_version(name))
            .collect();
        found.sort_by(|a, b| version::compare(b, a));
        found
    }

    pub fn exe_path(&self, version: &str) -> PathBuf {
        self.versions_dir.join(version).join(game_exe_name())
    }

    /// Downloads, checks and installs a release. `progress(done, total)` is called while
    /// downloading; setting `cancel` stops it. Returns the version folder or what went wrong.
    pub fn install(
        &self,
        release: &Release,
        cancel: &AtomicBool,
        progress: &mut dyn FnMut(u64, u64),
    ) -> Result<PathBuf, String> {
        let downloads = self.versions_dir.join(".downloads");
        fs::create_dir_all(&downloads).map_err(|_| self.write_problem())?;
        let zip_path = downloads.join(format!("{}.zip", release.version));
        let result = download(&release.url, release.size, &zip_path, cancel, progress)
            .and_then(|_| self.install_zip(&zip_path, &release.digest, &release.version));
        let _ = fs::remove_file(&zip_path);
        let _ = fs::remove_dir(&downloads);
        result
    }

    /// Checks the zip against the digest and unpacks it into `versions/<version>/`.
    pub fn install_zip(&self, zip_path: &Path, digest: &str, version: &str) -> Result<PathBuf, String> {
        if sha256_file(zip_path).map_err(|_| "The download was damaged. Try again.".to_string())? != digest {
            return Err("The download was damaged. Try again.".into());
        }
        let final_dir = self.versions_dir.join(version);
        let temp_dir = self.versions_dir.join(format!("{version}.tmp"));
        let _ = fs::remove_dir_all(&temp_dir);
        if unzip(zip_path, &temp_dir).is_err() {
            let _ = fs::remove_dir_all(&temp_dir);
            return Err(self.write_problem());
        }
        let _ = fs::remove_dir_all(&final_dir);
        if fs::rename(&temp_dir, &final_dir).is_err() {
            let _ = fs::remove_dir_all(&temp_dir);
            return Err(format!("Could not finish installing {version}."));
        }
        self.prune(&[]);
        Ok(final_dir)
    }

    /// Deletes all but the `KEEP` newest version folders. Folders named in `in_use`, or that
    /// cannot be deleted yet (a running game), stay and are tried again next time.
    pub fn prune(&self, in_use: &[String]) {
        for name in self.installed().iter().skip(KEEP) {
            if !in_use.contains(name) {
                let _ = fs::remove_dir_all(self.versions_dir.join(name));
            }
        }
    }

    fn write_problem(&self) -> String {
        format!(
            "Could not write to {}. Pick a folder you own.",
            self.versions_dir.display()
        )
    }
}

/// Lowercase hex SHA-256 of a file, like GitHub's asset `digest` without its `sha256:` prefix.
pub fn sha256_file(path: &Path) -> io::Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; CHUNK];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hasher.finalize().iter().map(|byte| format!("{byte:02x}")).collect())
}

fn download(
    url: &str,
    size: u64,
    target: &Path,
    cancel: &AtomicBool,
    progress: &mut dyn FnMut(u64, u64),
) -> Result<(), String> {
    let failed = || "The download failed. Check your connection and try again.".to_string();
    let client = reqwest::blocking::Client::builder()
        .user_agent(USER_AGENT)
        .connect_timeout(Duration::from_secs(10))
        .timeout(None)
        .build()
        .map_err(|_| failed())?;
    let mut response = client.get(url).send().map_err(|_| failed())?;
    if !response.status().is_success() {
        return Err(failed());
    }
    let total = response.content_length().unwrap_or(size);
    let mut file = File::create(target).map_err(|_| failed())?;
    let mut buffer = vec![0u8; CHUNK];
    let mut done: u64 = 0;
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err("Download cancelled.".into());
        }
        let read = response.read(&mut buffer).map_err(|_| failed())?;
        if read == 0 {
            break;
        }
        file.write_all(&buffer[..read]).map_err(|_| failed())?;
        done += read as u64;
        progress(done, total);
    }
    if total > 0 && done != total {
        return Err(failed());
    }
    Ok(())
}

fn unzip(zip_path: &Path, target: &Path) -> io::Result<()> {
    let mut archive = zip::ZipArchive::new(File::open(zip_path)?)?;
    fs::create_dir_all(target)?;
    for index in 0..archive.len() {
        let mut entry = archive.by_index(index)?;
        let Some(relative) = entry.enclosed_name() else {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "unsafe path in zip"));
        };
        let path = target.join(relative);
        if entry.is_dir() {
            fs::create_dir_all(&path)?;
            continue;
        }
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        io::copy(&mut entry, &mut File::create(&path)?)?;
        make_executable(&path)?;
    }
    Ok(())
}

#[cfg(unix)]
fn make_executable(path: &Path) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    if path.extension().is_some_and(|extension| extension == "x86_64") {
        fs::set_permissions(path, fs::Permissions::from_mode(0o755))?;
    }
    Ok(())
}

#[cfg(not(unix))]
fn make_executable(_path: &Path) -> io::Result<()> {
    Ok(())
}
