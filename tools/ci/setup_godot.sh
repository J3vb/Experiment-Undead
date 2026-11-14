#!/usr/bin/env bash
# Downloads Godot and the export templates needed for our presets.
# Usage: setup_godot.sh <version> <install_dir>
# Skips anything already present, so a restored cache makes this a no-op.
set -euo pipefail

VERSION="${1:?godot version}"
DIR="${2:?install dir}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
TEMPLATES="${HOME}/.local/share/godot/export_templates/${VERSION}.stable"

mkdir -p "$DIR" "$TEMPLATES"

if [ ! -x "$DIR/godot" ]; then
  curl -fsSL --retry 3 -o "$DIR/godot.zip" "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -qo "$DIR/godot.zip" -d "$DIR"
  mv "$DIR/Godot_v${VERSION}-stable_linux.x86_64" "$DIR/godot"
  chmod +x "$DIR/godot"
  rm "$DIR/godot.zip"
fi

NEEDED="version.txt linux_release.x86_64 windows_release_x86_64.exe windows_release_x86_64_console.exe"
missing=""
for f in $NEEDED; do
  [ -f "$TEMPLATES/$f" ] || missing="$missing templates/$f"
done
if [ -n "$missing" ]; then
  curl -fsSL --retry 3 -o "$DIR/templates.tpz" "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
  # shellcheck disable=SC2086
  unzip -qo -j "$DIR/templates.tpz" $missing -d "$TEMPLATES"
  rm "$DIR/templates.tpz"
fi

"$DIR/godot" --version
