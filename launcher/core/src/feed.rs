//! Reads the GitHub Releases list: the newest release a channel may install, and
//! whether it is newer than what is already installed. Same rules as the game's old
//! `ReleaseFeed`.

use crate::version;
use serde::Serialize;
use serde_json::Value;
use std::time::Duration;

pub const API_URL: &str = "https://api.github.com/repos/J3vb/Experiment-Undead/releases";
pub const WINDOWS_SUFFIX: &str = "-windows.zip";
pub const LINUX_SUFFIX: &str = "-linux.zip";
const DIGEST_PREFIX: &str = "sha256:";
pub const USER_AGENT: &str = "ExperimentUndead-launcher";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Channel {
    Stable,
    Test,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct Release {
    pub version: String,
    pub notes: String,
    pub url: String,
    pub digest: String,
    pub size: u64,
    pub page: String,
}

/// The zip name ending for this platform's game build.
pub fn platform_suffix() -> &'static str {
    if cfg!(windows) {
        WINDOWS_SUFFIX
    } else {
        LINUX_SUFFIX
    }
}

/// Downloads the releases list. Errors are plain text for the status line and the log.
pub fn fetch(api_url: &str) -> Result<Vec<Value>, String> {
    let client = reqwest::blocking::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(8))
        .build()
        .map_err(|error| error.to_string())?;
    let response = client.get(api_url).send().map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!("GitHub answered {}", response.status()));
    }
    response.json::<Vec<Value>>().map_err(|error| error.to_string())
}

/// Newest release on the channel with this platform's zip and a SHA-256 digest.
/// Stable sees only full releases; test sees pre-releases too.
pub fn newest(releases: &[Value], channel: Channel, suffix: &str) -> Option<Release> {
    releases
        .iter()
        .filter_map(|entry| installable(entry, channel, suffix))
        .max_by(|a, b| version::compare(&a.version, &b.version))
}

/// True when version is newer than every installed one.
pub fn is_newer(version: &str, installed: &[String]) -> bool {
    installed.iter().all(|other| version::compare(version, other).is_gt())
}

fn installable(entry: &Value, channel: Channel, suffix: &str) -> Option<Release> {
    let prerelease = entry["prerelease"].as_bool().unwrap_or(false);
    if entry["draft"].as_bool().unwrap_or(false) || (channel == Channel::Stable && prerelease) {
        return None;
    }
    let version = entry["tag_name"].as_str()?.trim_start_matches('v').to_string();
    if !version::is_release_version(&version) || (channel == Channel::Stable && version.contains('-')) {
        return None;
    }
    let asset = entry["assets"].as_array()?.iter().find(|asset| {
        let name = asset["name"].as_str().unwrap_or("");
        let digest = asset["digest"].as_str().unwrap_or("");
        name.ends_with(suffix) && digest.starts_with(DIGEST_PREFIX)
    })?;
    Some(Release {
        version,
        notes: entry["body"].as_str().unwrap_or("").to_string(),
        url: asset["browser_download_url"].as_str().unwrap_or("").to_string(),
        digest: asset["digest"].as_str()?.trim_start_matches(DIGEST_PREFIX).to_string(),
        size: asset["size"].as_u64().unwrap_or(0),
        page: entry["html_url"].as_str().unwrap_or("").to_string(),
    })
}
