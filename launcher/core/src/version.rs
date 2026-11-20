//! Version compare, the same rules as `Build.compare_versions()` in the game.
//! Both are checked against `tests/fixtures/version_table.json`.

use std::cmp::Ordering;

/// Numeric parts compare as numbers; a pre-release sorts before its release
/// (`0.2.0-test.3` < `0.2.0` < `0.2.1`); build metadata after `+` is ignored.
pub fn compare(a: &str, b: &str) -> Ordering {
    let (left_core, left_pre) = split(a);
    let (right_core, right_pre) = split(b);
    let order = compare_parts(&left_core, &right_core, true);
    if order != Ordering::Equal {
        return order;
    }
    match (left_pre, right_pre) {
        (None, None) => Ordering::Equal,
        (None, Some(_)) => Ordering::Greater,
        (Some(_), None) => Ordering::Less,
        (Some(left), Some(right)) => compare_parts(&left, &right, false),
    }
}

/// A full release (0.1.0) or a test release (0.1.0-test.2). Dev builds are neither.
pub fn is_release_version(version: &str) -> bool {
    let (core, pre) = match version.split_once('-') {
        Some((core, pre)) => (core, Some(pre)),
        None => (version, None),
    };
    let numbers: Vec<&str> = core.split('.').collect();
    if numbers.len() != 3 || !numbers.iter().all(|part| is_number(part)) {
        return false;
    }
    match pre {
        None => true,
        Some(pre) => pre.strip_prefix("test.").is_some_and(is_number),
    }
}

fn is_number(part: &str) -> bool {
    !part.is_empty() && part.bytes().all(|byte| byte.is_ascii_digit())
}

fn split(version: &str) -> (Vec<String>, Option<Vec<String>>) {
    let version = version.trim_start_matches('v');
    let version = version.split('+').next().unwrap_or("");
    let parts = |text: &str| text.split('.').map(str::to_string).collect::<Vec<String>>();
    match version.split_once('-') {
        Some((core, pre)) => (parts(core), Some(parts(pre))),
        None => (parts(version), None),
    }
}

/// Missing release parts count as 0; with more pre-release parts the version is newer.
fn compare_parts(left: &[String], right: &[String], pad_zero: bool) -> Ordering {
    for index in 0..left.len().max(right.len()) {
        if !pad_zero && (index >= left.len() || index >= right.len()) {
            return if index >= left.len() {
                Ordering::Less
            } else {
                Ordering::Greater
            };
        }
        let zero = String::from("0");
        let order = compare_part(left.get(index).unwrap_or(&zero), right.get(index).unwrap_or(&zero));
        if order != Ordering::Equal {
            return order;
        }
    }
    Ordering::Equal
}

fn compare_part(left: &str, right: &str) -> Ordering {
    match (left.parse::<i64>(), right.parse::<i64>()) {
        (Ok(a), Ok(b)) => a.cmp(&b),
        (Ok(_), Err(_)) => Ordering::Less,
        (Err(_), Ok(_)) => Ordering::Greater,
        (Err(_), Err(_)) => left.to_lowercase().cmp(&right.to_lowercase()),
    }
}
