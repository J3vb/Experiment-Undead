#!/usr/bin/env bash
# Exports the Windows, Linux and Linux Server presets into build/.
# Usage: export_all.sh <godot binary>
set -euo pipefail

GODOT="${1:?godot binary}"
cd "$(git rev-parse --show-toplevel)"
rm -rf build
mkdir -p build/windows build/linux build/server

export_preset() {
  local preset="$1" out="$2"
  echo "::group::Export $preset"
  "$GODOT" --headless --path . --export-release "$preset" "$out" 2>&1 | tee "build/export-${preset// /_}.log"
  echo "::endgroup::"
  if [ ! -s "$out" ] || grep -qE "SCRIPT ERROR|Parse Error|ERROR: Project export" "build/export-${preset// /_}.log"; then
    echo "::error::Export of $preset failed"
    exit 1
  fi
}

export_preset "Windows" build/windows/ExperimentUndead.exe
export_preset "Linux" build/linux/ExperimentUndead.x86_64
export_preset "Linux Server" build/server/ExperimentUndead-server.x86_64
rm -f build/export-*.log
