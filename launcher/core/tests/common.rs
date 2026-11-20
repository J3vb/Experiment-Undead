//! Shared test helpers: fixture paths and a tiny local HTTP server.

#![allow(dead_code)]

use std::io::{Read, Write};
use std::net::TcpListener;
use std::path::PathBuf;
use std::thread;

pub fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/fixtures")
        .join(name)
}

/// Serves `body` for every request on a free local port. `cut_at` promises the whole
/// body in Content-Length but closes the connection early. Returns the base URL.
pub fn serve(body: Vec<u8>, cut_at: Option<usize>) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").expect("listener");
    let address = listener.local_addr().expect("address");
    thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(mut stream) = stream else { continue };
            let mut request = Vec::new();
            let mut byte = [0u8; 1];
            while !request.ends_with(b"\r\n\r\n") && stream.read(&mut byte).unwrap_or(0) == 1 {
                request.push(byte[0]);
            }
            let head = format!(
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            );
            let _ = stream.write_all(head.as_bytes());
            let _ = stream.write_all(&body[..cut_at.unwrap_or(body.len())]);
        }
    });
    format!("http://{address}")
}

/// A zip with the game exe and pck at its root, like a release zip.
pub fn game_zip(exe_name: &str) -> Vec<u8> {
    let mut buffer = std::io::Cursor::new(Vec::new());
    {
        let mut writer = zip::ZipWriter::new(&mut buffer);
        let options = zip::write::SimpleFileOptions::default();
        writer.start_file(exe_name, options).expect("exe entry");
        writer.write_all(b"game exe").expect("exe data");
        writer.start_file("ExperimentUndead.pck", options).expect("pck entry");
        writer.write_all(b"game pack").expect("pck data");
        writer.finish().expect("zip");
    }
    buffer.into_inner()
}

pub fn temp_dir(name: &str) -> PathBuf {
    let path = std::env::temp_dir().join(format!("eu-launcher-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).expect("temp dir");
    path
}
