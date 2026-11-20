"""Tests for tools/ci/launcher_release.py; stdlib only."""

import json
import sys
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import launcher_release


class StampTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.conf = self.dir / "tauri.conf.json"
        self.conf.write_text(json.dumps({"productName": "X", "version": "0.0.0"}), encoding="utf-8")
        self.cargo = self.dir / "Cargo.toml"
        self.cargo.write_text('[workspace.package]\nversion = "0.0.0"\nedition = "2021"\n', encoding="utf-8")

    def test_writes_the_version_into_both_files(self):
        launcher_release.stamp("0.1.0-test.2", self.conf, self.cargo)
        self.assertEqual(json.loads(self.conf.read_text(encoding="utf-8"))["version"], "0.1.0-test.2")
        self.assertIn('version = "0.1.0-test.2"', self.cargo.read_text(encoding="utf-8"))
        self.assertIn('edition = "2021"', self.cargo.read_text(encoding="utf-8"))

    def test_refuses_dev_versions(self):
        with self.assertRaises(ValueError):
            launcher_release.stamp("0.1.0-dev.3+abc", self.conf, self.cargo)

    def test_the_real_files_have_a_version_to_stamp(self):
        conf = json.loads(launcher_release.TAURI_CONF.read_text(encoding="utf-8"))
        self.assertIn("version", conf)
        self.assertRegex(launcher_release.CARGO_TOML.read_text(encoding="utf-8"), r'(?m)^version = "')
        self.assertTrue(conf["plugins"]["updater"]["pubkey"], "updater public key")


class ManifestTests(unittest.TestCase):
    def test_has_what_the_tauri_updater_reads(self):
        now = datetime(2026, 11, 20, 6, 0, tzinfo=UTC)
        data = launcher_release.manifest("0.1.0-test.2", "https://x/Setup.exe", "c2lnbmF0dXJl\n", now)
        self.assertEqual(data["version"], "0.1.0-test.2")
        self.assertEqual(data["pub_date"], "2026-11-20T06:00:00Z")
        self.assertEqual(
            data["platforms"]["windows-x86_64"], {"signature": "c2lnbmF0dXJl", "url": "https://x/Setup.exe"}
        )
        self.assertTrue(data["notes"])


if __name__ == "__main__":
    unittest.main()
