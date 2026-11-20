#!/bin/bash
# Installs Godot (headless) and the lint tools so cloud sessions can run the same checks as CI.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}"

# The vendored Elephant-Goldfish Model plugin (plan reviews), in local settings so no machine path is committed.
if command -v claude >/dev/null; then
  { claude plugin marketplace add "$PWD/.agents/plugins/egm" --scope local \
    && claude plugin install egm@egm --scope local; } >/dev/null 2>&1 \
    || echo "session-start: could not enable the egm plugin" >&2
fi

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

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

# Software Vulkan (lavapipe) and a virtual display, so cloud renders use Forward+ (real lighting).
if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ] || ! command -v xvfb-run >/dev/null; then
  { apt-get install -y -q mesa-vulkan-drivers xvfb >/dev/null 2>&1 \
    || { apt-get update -q >/dev/null 2>&1 && apt-get install -y -q mesa-vulkan-drivers xvfb >/dev/null 2>&1; }; } \
    || echo "session-start: could not install lavapipe/xvfb; renders fall back to opengl3" >&2
fi

echo "export PATH=\"$BIN:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
