//! The Host a server page: start, stop and watch a dedicated server run by the newest
//! installed game (docs/plans/separate-launcher.md, step 4).

use crate::Launcher;
use launcher_core::log;
use serde::Serialize;
use std::time::Duration;
use tauri::{AppHandle, State};

#[derive(Serialize)]
pub struct HostStatus {
    /// Version of the running server, or None.
    running: Option<String>,
    port: u16,
    max_players: u8,
    /// What Start would run.
    installed: Option<String>,
}

#[tauri::command]
pub fn host_status(launcher: State<'_, Launcher>) -> Result<HostStatus, String> {
    let mut host = launcher.host.lock().map_err(|error| error.to_string())?;
    if let Some(code) = host.poll() {
        log::write(&launcher.data_dir, "info", "server_exited", &code.to_string());
    }
    let saved = launcher.settings.lock().map_err(|error| error.to_string())?;
    Ok(HostStatus {
        running: host.running(),
        port: saved.port,
        max_players: saved.max_players,
        installed: launcher.installer().installed().into_iter().next(),
    })
}

/// Saves the port and player limit, then starts the newest installed game as a server.
#[tauri::command]
pub fn host_start(launcher: State<'_, Launcher>, port: u16, max_players: u8) -> Result<(), String> {
    {
        let mut saved = launcher.settings.lock().map_err(|error| error.to_string())?;
        saved.port = port.max(1);
        saved.max_players = max_players.clamp(1, launcher_core::host::MAX_PLAYERS);
        saved.save(&launcher.data_dir)?;
    }
    let installer = launcher.installer();
    let version = installer
        .installed()
        .into_iter()
        .next()
        .ok_or("Install the game before hosting a server.")?;
    let mut host = launcher.host.lock().map_err(|error| error.to_string())?;
    let result = host.start(&installer.exe_path(&version), &version, port, max_players);
    match &result {
        Ok(()) => log::write(
            &launcher.data_dir,
            "info",
            "server_started",
            &format!("{version} port {port}"),
        ),
        Err(problem) => log::write(&launcher.data_dir, "warn", "server_start_failed", problem),
    }
    result
}

#[tauri::command]
pub fn host_stop(launcher: State<'_, Launcher>) -> Result<(), String> {
    launcher.host.lock().map_err(|error| error.to_string())?.stop();
    log::write(&launcher.data_dir, "info", "server_stop_requested", "");
    Ok(())
}

/// Opens the folder with `server.log` in the file manager.
#[tauri::command]
pub fn open_logs(launcher: State<'_, Launcher>) -> Result<(), String> {
    let dir = launcher.host.lock().map_err(|error| error.to_string())?.dir.clone();
    std::fs::create_dir_all(&dir).map_err(|error| error.to_string())?;
    let opener = if cfg!(windows) {
        "explorer"
    } else if cfg!(target_os = "macos") {
        "open"
    } else {
        "xdg-open"
    };
    std::process::Command::new(opener)
        .arg(&dir)
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("Could not open {}: {error}", dir.display()))
}

/// Closes the launcher, stopping a running server first (it gets 10 seconds to save).
#[tauri::command]
pub fn quit(app: AppHandle, launcher: State<'_, Launcher>) -> Result<(), String> {
    let mut host = launcher.host.lock().map_err(|error| error.to_string())?;
    if host.running().is_some() {
        host.stop_and_wait(Duration::from_secs(10));
        log::write(&launcher.data_dir, "info", "server_exited", "launcher closed");
    }
    app.exit(0);
    Ok(())
}
