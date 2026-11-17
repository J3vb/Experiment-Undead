#!/usr/bin/env bash
# Launcher end to end (F-65 step 5): serves a fake releases list whose newer release is the
# freshly exported Linux build under version 99.0.0, starts the exported client from a root
# folder with the launcher forced open, and requires it to install versions/99.0.0/, start it,
# and the started copy to refresh the root copy.
# Usage: launcher_e2e.sh <build dir with linux/>
set -uo pipefail

build="$(cd "${1:?build dir}" && pwd)"
work="$(mktemp -d)"
root="$work/root"
serve="$work/serve"
port=8765
cfg="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Experiment Undead/launcher.cfg"
mkdir -p "$root" "$serve"
cp -a "$build/linux/." "$root/"
(cd "$build/linux" && zip -qr "$serve/ExperimentUndead-99.0.0-linux.zip" .)
digest="$(sha256sum "$serve/ExperimentUndead-99.0.0-linux.zip" | cut -d' ' -f1)"
size="$(stat -c %s "$serve/ExperimentUndead-99.0.0-linux.zip")"
cat > "$serve/releases.json" <<JSON
[{"tag_name": "v99.0.0", "name": "Experiment Undead 99.0.0", "prerelease": false, "draft": false,
  "body": "Launcher test", "html_url": "http://127.0.0.1:$port/",
  "assets": [{"name": "ExperimentUndead-99.0.0-linux.zip", "digest": "sha256:$digest", "size": $size,
              "browser_download_url": "http://127.0.0.1:$port/ExperimentUndead-99.0.0-linux.zip"}]}]
JSON
rm -f "$cfg"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$serve" > "$work/http.log" 2>&1 &
http_pid=$!
sleep 1

fail=0
timeout 120 "$root/ExperimentUndead.x86_64" --headless -- --launcher \
  "--releases-api=http://127.0.0.1:$port/releases.json" --launcher-autoplay > "$work/launcher.log" 2>&1
code=$?
for _ in $(seq 1 60); do
  grep -q "root_version=\"99.0.0\"" "$cfg" 2>/dev/null && break
  sleep 1
done
echo "--- launcher.log"
cat "$work/launcher.log"
echo "--- launcher.cfg"
cat "$cfg" 2>/dev/null
kill "$http_pid" 2>/dev/null

if [ "$code" -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$work/launcher.log"; then
  echo "::error::Launcher did not exit cleanly (exit $code)"
  fail=1
fi
if [ ! -x "$root/versions/99.0.0/ExperimentUndead.x86_64" ] || [ ! -f "$root/versions/99.0.0/ExperimentUndead.pck" ]; then
  echo "::error::Launcher did not install versions/99.0.0/"
  fail=1
fi
if ! grep -q "root_version=\"99.0.0\"" "$cfg" 2>/dev/null; then
  echo "::error::The started copy did not refresh the root copy"
  fail=1
fi
rm -rf "$work"
exit "$fail"
