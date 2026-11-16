#!/bin/bash
# Installs Godot (headless) and the lint tools so cloud sessions can run the same checks as CI.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

GODOT_VERSION=4.7.2
GDTOOLKIT_VERSION=4.5.0
RUFF_VERSION=0.17.5
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

if ! "$BIN/godot" --version 2>/dev/null | grep -q "^${GODOT_VERSION}\.stable"; then
  tmp="$(mktemp -d)"
  curl -fsSL --retry 3 -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -qo "$tmp/godot.zip" -d "$tmp"
  mv "$tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$BIN/godot"
  chmod +x "$BIN/godot"
  rm -rf "$tmp"
fi

pyhashes="$(python3 -I -c 'import sysconfig; print(sysconfig.get_path("purelib"))')/.session-start.sha256"
if ! sha256sum --check --status "$pyhashes" 2>/dev/null; then
  rm -f "$pyhashes"
  PIP_ROOT_USER_ACTION=ignore python3 -m pip install -q "gdtoolkit==${GDTOOLKIT_VERSION}" "ruff==${RUFF_VERSION}"
  sha256sum .claude/hooks/session-start.sh > "$pyhashes" || rm -f "$pyhashes"
fi

echo "export PATH=\"$BIN:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
