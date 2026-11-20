//! Stands in for the game in the host tests: prints its arguments, waits for its
//! `--stop-file=`, then exits with the number written in it (0 for any other text).

use std::path::PathBuf;
use std::time::Duration;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    println!("{}", args.join(" "));
    let stop_file = args
        .iter()
        .find_map(|arg| arg.strip_prefix("--stop-file=").map(PathBuf::from))
        .expect("--stop-file=");
    while !stop_file.exists() {
        std::thread::sleep(Duration::from_millis(20));
    }
    std::thread::sleep(Duration::from_millis(50));
    let code = std::fs::read_to_string(&stop_file)
        .ok()
        .and_then(|text| text.trim().parse().ok())
        .unwrap_or(0);
    std::process::exit(code);
}
