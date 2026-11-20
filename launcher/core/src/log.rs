//! One JSON line per event in `launcher.log`, like the game's logs (docs/LOGGING.md).

use std::fs::OpenOptions;
use std::io::Write;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

/// Appends `{"t": <unix seconds>, "level": .., "event": .., "message": ..}`. Never fails loudly:
/// a launcher that cannot write its log still installs and plays.
pub fn write(folder: &Path, level: &str, event: &str, message: &str) {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|time| time.as_secs())
        .unwrap_or(0);
    let line = serde_json::json!({"t": seconds, "level": level, "event": event, "message": message});
    if std::fs::create_dir_all(folder).is_err() {
        return;
    }
    if let Ok(mut file) = OpenOptions::new()
        .create(true)
        .append(true)
        .open(folder.join("launcher.log"))
    {
        let _ = writeln!(file, "{line}");
    }
}
