"""Release helpers for the separate launcher (docs/plans/separate-launcher.md, step 2).

stamp <version>: writes the release version into launcher/src-tauri/tauri.conf.json and
launcher/Cargo.toml, so the launcher knows its own version and the updater can compare.
manifest: writes latest.json, the file Tauri's updater reads to find a newer signed setup exe.
"""

import argparse
import json
import re
import sys
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAURI_CONF = ROOT / "launcher" / "src-tauri" / "tauri.conf.json"
CARGO_TOML = ROOT / "launcher" / "Cargo.toml"
RELEASE_VERSION = re.compile(r"^\d+\.\d+\.\d+(-test\.\d+)?$")
NOTES = "A new launcher is ready. It installs itself and restarts."


def stamp(version: str, tauri_conf: Path = TAURI_CONF, cargo_toml: Path = CARGO_TOML) -> None:
    if not RELEASE_VERSION.match(version):
        raise ValueError(f"not a release version: {version}")
    conf = json.loads(tauri_conf.read_text(encoding="utf-8"))
    conf["version"] = version
    tauri_conf.write_text(json.dumps(conf, indent=2) + "\n", encoding="utf-8")
    text = cargo_toml.read_text(encoding="utf-8")
    text, count = re.subn(r'(?m)^version = "[^"]*"', f'version = "{version}"', text, count=1)
    if count != 1:
        raise ValueError(f"no version line in {cargo_toml}")
    cargo_toml.write_text(text, encoding="utf-8")


def manifest(version: str, setup_url: str, signature: str, now: datetime | None = None) -> dict:
    moment = (now or datetime.now(UTC)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "version": version,
        "notes": NOTES,
        "pub_date": moment,
        "platforms": {"windows-x86_64": {"signature": signature.strip(), "url": setup_url}},
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    stamp_cmd = commands.add_parser("stamp")
    stamp_cmd.add_argument("version")
    manifest_cmd = commands.add_parser("manifest")
    manifest_cmd.add_argument("--version", required=True)
    manifest_cmd.add_argument("--setup-url", required=True)
    manifest_cmd.add_argument("--signature-file", type=Path, required=True)
    manifest_cmd.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.command == "stamp":
        stamp(args.version)
    else:
        data = manifest(args.version, args.setup_url, args.signature_file.read_text(encoding="utf-8"))
        args.out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
