//! Host a server: runs an installed game build as a headless dedicated server and stops it
//! through its stop file, the same way the Docker image does (docs/RELEASING.md).

use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

/// Same as `Net.DEFAULT_PORT` and `Net.MAX_PLAYERS` in the game.
pub const DEFAULT_PORT: u16 = 7777;
pub const MAX_PLAYERS: u8 = 8;
pub const LOG_FILE: &str = "server.log";
const STOP_FILE: &str = "server.stop";

/// The game's command line for a headless server on `port` for at most `max_players`
/// (clamped to 1-8), quitting when `stop_file` appears.
pub fn server_args(port: u16, max_players: u8, stop_file: &Path) -> Vec<String> {
    vec![
        "--headless".into(),
        "--".into(),
        "--server".into(),
        format!("--port={}", port.max(1)),
        format!("--max-players={}", max_players.clamp(1, MAX_PLAYERS)),
        format!("--stop-file={}", stop_file.display()),
    ]
}

pub struct Host {
    /// Holds the stop file and the server log.
    pub dir: PathBuf,
    child: Option<Child>,
    version: String,
}

impl Host {
    pub fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            child: None,
            version: String::new(),
        }
    }

    pub fn stop_file(&self) -> PathBuf {
        self.dir.join(STOP_FILE)
    }

    /// Starts `exe` (the game of `version`) as a server, its output going to `server.log`.
    pub fn start(&mut self, exe: &Path, version: &str, port: u16, max_players: u8) -> Result<(), String> {
        if self.running().is_some() {
            return Err("A server is already running.".into());
        }
        fs::create_dir_all(&self.dir).map_err(|error| error.to_string())?;
        let _ = fs::remove_file(self.stop_file());
        let log = File::create(self.dir.join(LOG_FILE)).map_err(|error| error.to_string())?;
        let mut command = Command::new(exe);
        command
            .args(server_args(port, max_players, &self.stop_file()))
            .current_dir(exe.parent().unwrap_or(&self.dir))
            .stdin(Stdio::null())
            .stdout(log.try_clone().map_err(|error| error.to_string())?)
            .stderr(log);
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            const CREATE_NO_WINDOW: u32 = 0x0800_0000;
            command.creation_flags(CREATE_NO_WINDOW);
        }
        let child = command
            .spawn()
            .map_err(|error| format!("Could not start the server: {error}"))?;
        self.child = Some(child);
        self.version = version.to_string();
        Ok(())
    }

    /// The running server's version, or None once it has exited.
    pub fn running(&mut self) -> Option<String> {
        self.poll();
        self.child.as_ref().map(|_| self.version.clone())
    }

    /// Exit code of a server that has just exited (-1 when it was killed or crashed hard).
    /// None while it runs or when none was started.
    pub fn poll(&mut self) -> Option<i32> {
        let status = self.child.as_mut()?.try_wait().ok()??;
        self.child = None;
        self.version.clear();
        Some(status.code().unwrap_or(-1))
    }

    /// Asks the server to quit through its stop file.
    pub fn stop(&self) {
        if self.child.is_some() {
            let _ = fs::write(self.stop_file(), "stop");
        }
    }

    /// Stops the server and waits up to `timeout` for it, then kills it.
    pub fn stop_and_wait(&mut self, timeout: Duration) {
        self.stop();
        let start = Instant::now();
        while self.running().is_some() && start.elapsed() < timeout {
            std::thread::sleep(Duration::from_millis(100));
        }
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
            let _ = child.wait();
            self.version.clear();
        }
    }
}
