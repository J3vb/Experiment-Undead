use launcher_core::feed::{is_newer, newest, Channel, LINUX_SUFFIX, WINDOWS_SUFFIX};
use serde_json::Value;

mod common;

fn releases() -> Vec<Value> {
    let text = std::fs::read_to_string(common::fixture("releases.json")).expect("releases fixture");
    serde_json::from_str(&text).expect("releases json")
}

#[test]
fn stable_skips_pre_releases_and_drafts() {
    let release = newest(&releases(), Channel::Stable, WINDOWS_SUFFIX).expect("a stable release");
    assert_eq!(release.version, "0.1.1");
    assert_eq!(release.digest, "ccc");
    assert_eq!(release.notes, "Stable notes");
}

#[test]
fn test_channel_takes_pre_releases() {
    let release = newest(&releases(), Channel::Test, WINDOWS_SUFFIX).expect("a test release");
    assert_eq!(release.version, "0.2.0-test.1");
}

#[test]
fn release_without_digest_for_this_platform_is_skipped() {
    let release = newest(&releases(), Channel::Stable, LINUX_SUFFIX).expect("a linux release");
    assert_eq!(release.version, "0.1.0");
}

#[test]
fn nothing_newer_than_installed() {
    let installed = vec!["0.1.1".to_string(), "0.1.0".to_string()];
    assert!(!is_newer("0.1.1", &installed));
    assert!(is_newer("0.2.0-test.1", &installed));
    assert!(is_newer("0.1.0", &[]));
}

#[test]
fn garbage_entries_are_ignored() {
    let list: Vec<Value> = serde_json::from_str(r#"[1, "x", {"tag_name": 5}, {"tag_name": "v1.0.0"}]"#).unwrap();
    assert!(newest(&list, Channel::Test, WINDOWS_SUFFIX).is_none());
}
