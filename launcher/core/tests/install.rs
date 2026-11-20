use launcher_core::feed::Release;
use launcher_core::install::{game_exe_name, sha256_file, Installer, KEEP};
use std::sync::atomic::AtomicBool;

mod common;

fn release(url: String, digest: String, version: &str) -> Release {
    Release {
        version: version.into(),
        notes: String::new(),
        url,
        digest,
        size: 0,
        page: String::new(),
    }
}

fn digest_of(bytes: &[u8], dir: &std::path::Path) -> String {
    let path = dir.join("digest.bin");
    std::fs::write(&path, bytes).unwrap();
    let digest = sha256_file(&path).unwrap();
    std::fs::remove_file(path).unwrap();
    digest
}

#[test]
fn good_zip_lands_in_its_version_folder() {
    let dir = common::temp_dir("good");
    let zip = common::game_zip(game_exe_name());
    let digest = digest_of(&zip, &dir);
    let installer = Installer::new(dir.join("versions"));
    let mut calls = 0;
    let folder = installer
        .install(
            &release(common::serve(zip, None), digest, "0.1.1"),
            &AtomicBool::new(false),
            &mut |_, _| calls += 1,
        )
        .expect("installed");
    assert!(folder.join(game_exe_name()).is_file());
    assert!(folder.join("ExperimentUndead.pck").is_file());
    assert_eq!(installer.installed(), vec!["0.1.1".to_string()]);
    assert!(calls > 0);
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(folder.join(game_exe_name()))
            .unwrap()
            .permissions()
            .mode();
        assert_eq!(mode & 0o111, 0o111);
    }
}

#[test]
fn wrong_digest_leaves_nothing_behind() {
    let dir = common::temp_dir("digest");
    let installer = Installer::new(dir.join("versions"));
    let zip = common::game_zip(game_exe_name());
    let result = installer.install(
        &release(common::serve(zip, None), "00".into(), "0.1.1"),
        &AtomicBool::new(false),
        &mut |_, _| {},
    );
    assert!(result.is_err());
    assert!(installer.installed().is_empty());
    assert!(!dir.join("versions/0.1.1.tmp").exists());
}

#[test]
fn cut_off_download_leaves_nothing_behind() {
    let dir = common::temp_dir("cut");
    let zip = common::game_zip(game_exe_name());
    let digest = digest_of(&zip, &dir);
    let installer = Installer::new(dir.join("versions"));
    let cut = zip.len() / 2;
    let result = installer.install(
        &release(common::serve(zip, Some(cut)), digest, "0.1.1"),
        &AtomicBool::new(false),
        &mut |_, _| {},
    );
    assert!(result.is_err());
    assert!(installer.installed().is_empty());
}

#[test]
fn cancel_stops_the_download() {
    let dir = common::temp_dir("cancel");
    let zip = common::game_zip(game_exe_name());
    let installer = Installer::new(dir.join("versions"));
    let result = installer.install(
        &release(common::serve(zip, None), "x".into(), "0.1.1"),
        &AtomicBool::new(true),
        &mut |_, _| {},
    );
    assert_eq!(result.unwrap_err(), "Download cancelled.");
}

#[test]
fn only_the_newest_folders_stay() {
    let dir = common::temp_dir("prune");
    let versions = dir.join("versions");
    for name in ["0.1.0", "0.1.1", "0.2.0-test.1", "0.1.2.tmp", "notes"] {
        std::fs::create_dir_all(versions.join(name)).unwrap();
    }
    let installer = Installer::new(versions.clone());
    installer.prune(&["0.1.0".to_string()]);
    assert_eq!(
        installer.installed(),
        vec!["0.2.0-test.1".to_string(), "0.1.1".to_string(), "0.1.0".to_string()]
    );
    installer.prune(&[]);
    assert_eq!(installer.installed().len(), KEEP);
    assert!(versions.join("notes").exists());
}

#[test]
fn installing_keeps_the_version_a_server_runs() {
    let dir = common::temp_dir("in-use");
    let mut installer = Installer::new(dir.join("versions"));
    for version in ["0.1.0", "0.1.1"] {
        std::fs::create_dir_all(installer.versions_dir.join(version)).unwrap();
    }
    installer.in_use = vec!["0.1.0".to_string()];
    let zip_path = dir.join("game.zip");
    std::fs::write(&zip_path, common::game_zip(game_exe_name())).unwrap();
    let digest = sha256_file(&zip_path).unwrap();
    installer.install_zip(&zip_path, &digest, "0.1.2").expect("installed");
    assert_eq!(installer.installed(), vec!["0.1.2", "0.1.1", "0.1.0"]);
}
