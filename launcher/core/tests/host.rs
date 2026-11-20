use launcher_core::host::{server_args, Host, LOG_FILE};
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

mod common;

/// The fake server `cargo test` builds from `examples/fake_server.rs`.
fn fake_server() -> PathBuf {
    let deps = std::env::current_exe().unwrap();
    let name = format!("fake_server{}", std::env::consts::EXE_SUFFIX);
    deps.parent().unwrap().parent().unwrap().join("examples").join(name)
}

fn wait_for_exit(host: &mut Host) -> Option<i32> {
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(10) {
        if let Some(code) = host.poll() {
            return Some(code);
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    None
}

#[test]
fn server_args_match_the_game_and_clamp() {
    let stop = Path::new("/tmp/eu.stop");
    assert_eq!(
        server_args(7790, 4, stop),
        vec![
            "--headless",
            "--",
            "--server",
            "--port=7790",
            "--max-players=4",
            "--stop-file=/tmp/eu.stop"
        ]
    );
    let clamped = server_args(0, 99, stop);
    assert_eq!(clamped[3], "--port=1");
    assert_eq!(clamped[4], "--max-players=8");
    assert_eq!(server_args(7777, 0, stop)[4], "--max-players=1");
}

#[test]
fn start_runs_the_game_as_a_server_and_stop_ends_it() {
    let dir = common::temp_dir("host");
    let mut host = Host::new(dir.join("server"));
    host.start(&fake_server(), "0.1.1", 7790, 4).expect("started");
    assert_eq!(host.running().as_deref(), Some("0.1.1"));
    assert!(
        host.start(&fake_server(), "0.1.1", 7790, 4).is_err(),
        "one server at a time"
    );
    host.stop();
    assert_eq!(wait_for_exit(&mut host), Some(0));
    assert_eq!(host.running(), None);
    let log = std::fs::read_to_string(host.dir.join(LOG_FILE)).unwrap();
    assert!(
        log.contains("--server --port=7790 --max-players=4 --stop-file="),
        "{log}"
    );
}

#[test]
fn exit_code_is_reported_once() {
    let dir = common::temp_dir("host-code");
    let mut host = Host::new(dir.join("server"));
    host.start(&fake_server(), "0.1.1", 7790, 4).expect("started");
    std::fs::write(host.stop_file(), "3").unwrap();
    assert_eq!(wait_for_exit(&mut host), Some(3));
    assert_eq!(host.poll(), None);
}

#[test]
fn a_new_start_clears_an_old_stop_file() {
    let dir = common::temp_dir("host-stale");
    let mut host = Host::new(dir.join("server"));
    std::fs::create_dir_all(&host.dir).unwrap();
    std::fs::write(host.stop_file(), "stop").unwrap();
    host.start(&fake_server(), "0.1.1", 7790, 4).expect("started");
    std::thread::sleep(Duration::from_millis(200));
    assert_eq!(
        host.running().as_deref(),
        Some("0.1.1"),
        "an old stop file does not stop it"
    );
    host.stop_and_wait(Duration::from_secs(10));
    assert_eq!(host.running(), None);
}

#[test]
fn missing_game_is_a_plain_error() {
    let dir = common::temp_dir("host-missing");
    let mut host = Host::new(dir.join("server"));
    let problem = host.start(&dir.join("nope.exe"), "0.1.1", 7790, 4).unwrap_err();
    assert!(problem.starts_with("Could not start the server"), "{problem}");
    assert_eq!(host.running(), None);
}
