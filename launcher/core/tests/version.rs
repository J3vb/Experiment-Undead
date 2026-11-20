use launcher_core::version::{compare, is_release_version};
use std::cmp::Ordering;

mod common;

#[test]
fn shared_table_matches_the_game() {
    let text = std::fs::read_to_string(common::fixture("version_table.json")).expect("version table");
    let rows: Vec<(String, String, i32)> = serde_json::from_str(&text).expect("table rows");
    assert!(rows.len() >= 10);
    for (a, b, expected) in rows {
        let want = expected.cmp(&0);
        assert_eq!(compare(&a, &b), want, "{a} vs {b}");
        assert_eq!(compare(&b, &a), want.reverse(), "{b} vs {a}");
    }
}

#[test]
fn release_versions() {
    assert!(is_release_version("0.1.0"));
    assert!(is_release_version("0.1.0-test.2"));
    assert!(!is_release_version("0.1.0-dev.3+abc"));
    assert!(!is_release_version("0.1"));
    assert!(!is_release_version("0.1.0-test."));
    assert_eq!(compare("0.1.0-test.2", "0.1.0-test.2"), Ordering::Equal);
}
