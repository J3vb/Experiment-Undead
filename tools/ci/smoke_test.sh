#!/usr/bin/env bash
# Boots the exported Linux client and server headless, joins the server with
# the exported client, then stops the server. Fails on script errors, crashes,
# non-zero exit codes, or a server that never becomes ready or never stops.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)/build"
fail=0
errors="SCRIPT ERROR|Parse Error"

echo "::group::Client boot"
timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 600 -- --from-launcher > client.log 2>&1
code=$?
cat client.log
echo "::endgroup::"
if [ "$code" -ne 0 ] || grep -qE "$errors" client.log; then
  echo "::error::Exported client failed to boot cleanly (exit $code)"
  fail=1
fi

echo "::group::Content survives export"
# Release templates ignore -s, so the editor binary runs the check against the exported pack.
godot_bin="$(command -v godot || echo "$HOME/godot/godot")"
if ! timeout 60 "$godot_bin" --headless --main-pack linux/ExperimentUndead.pck \
    -s "$(git rev-parse --show-toplevel)/tools/ci/export_content_check.gd"; then
  echo "::error::Exported content lost data (see the lines above)"
  fail=1
fi
echo "::endgroup::"

echo "::group::Server boot, join and stop"
stop="$(mktemp -u)"
EU_STOP_FILE="$stop" server/ExperimentUndead-server.x86_64 --headless > server.log 2>&1 &
pid=$!
for _ in $(seq 1 60); do
  grep -q "Server ready" server.log && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done

joined=0
join_code=0
if grep -q "Server ready" server.log; then
  timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 900 -- --join=127.0.0.1:7777 > join.log 2>&1
  join_code=$?
  grep -q "Player connected" server.log && joined=1
fi
alive_after_join=0
kill -0 "$pid" 2>/dev/null && alive_after_join=1

touch "$stop"
hung=0
timeout 15 tail --pid="$pid" -f /dev/null || hung=1
if [ "$hung" -eq 1 ]; then
  kill -9 "$pid" 2>/dev/null
fi
wait "$pid"
server_code=$?
echo "--- server.log"
cat server.log
echo "--- join.log"
cat join.log 2>/dev/null
echo "::endgroup::"

if ! grep -q "Server ready" server.log; then
  echo "::error::Exported server never reported ready"
  fail=1
fi
if [ "$joined" -ne 1 ]; then
  echo "::error::Exported client could not join the exported server"
  fail=1
fi
if [ "$join_code" -ne 0 ]; then
  echo "::error::Joining client did not exit cleanly (exit $join_code)"
  fail=1
fi
if [ "$alive_after_join" -ne 1 ]; then
  echo "::error::Exported server died while a player was connected (exit $server_code)"
  fail=1
fi
if [ "$hung" -eq 1 ]; then
  echo "::error::Exported server did not exit within 15 s of the stop request"
  fail=1
fi
if [ "$server_code" -ne 0 ] || ! grep -q "Server stopped" server.log; then
  echo "::error::Exported server did not stop cleanly (exit $server_code)"
  fail=1
fi
if grep -qE "$errors" server.log join.log 2>/dev/null; then
  echo "::error::Script errors in the exported server or joining client"
  fail=1
fi

# The newest stable release that is not this build must be refused cleanly by
# this build's server (F-65 step 3). Releases before the JSON handshake
# (protocol 17) cannot read the refusal, so they are skipped.
old_client_check() {
  local own tag old_dir data_dir stop2 pid2 protocol refused=0
  own="v$(sed -n 's/.*"version": "\(.*\)".*/\1/p' ../version.json)"
  if ! command -v gh > /dev/null || [ -z "${GH_TOKEN:-}" ]; then
    echo "Old client check skipped: no older release (gh or GH_TOKEN missing)"
    return 0
  fi
  tag=""
  for candidate in $(gh release list --exclude-drafts --exclude-pre-releases --limit 20 \
      --json tagName -q '.[].tagName' 2>/dev/null); do
    [ "$candidate" = "$own" ] && continue
    if gh release view "$candidate" --json assets -q '.assets[].name' | grep -q -- '-linux\.zip$'; then
      tag="$candidate"
      break
    fi
  done
  if [ -z "$tag" ]; then
    echo "Old client check skipped: no older release"
    return 0
  fi
  old_dir="$(mktemp -d)"
  data_dir="$(mktemp -d)"
  gh release download "$tag" -p '*-linux.zip' -D "$old_dir" || { echo "::error::Could not download $tag"; return 1; }
  unzip -q "$old_dir"/*-linux.zip -d "$old_dir/client"
  chmod +x "$old_dir"/client/*.x86_64
  stop2="$(mktemp -u)"
  EU_STOP_FILE="$stop2" server/ExperimentUndead-server.x86_64 --headless > old_server.log 2>&1 &
  pid2=$!
  for _ in $(seq 1 60); do
    grep -q "Server ready" old_server.log && break
    sleep 0.5
  done
  XDG_DATA_HOME="$data_dir" timeout 20 "$old_dir"/client/*.x86_64 --headless --quit-after 1200 \
    -- --join=127.0.0.1:7777 > old_client.log 2>&1 &
  local client_pid=$!
  for _ in $(seq 1 30); do
    if grep -h '"join_refused"' "$data_dir"/godot/app_userdata/*/logs/*.jsonl 2>/dev/null | grep -q WRONG_VERSION; then
      refused=1
      break
    fi
    sleep 0.5
  done
  kill "$client_pid" 2>/dev/null
  touch "$stop2"
  timeout 15 tail --pid="$pid2" -f /dev/null || kill -9 "$pid2" 2>/dev/null
  protocol="$(sed -n 's/.*protocol \([0-9]*\)).*/\1/p' old_client.log | head -1)"
  echo "--- old client $tag (protocol ${protocol:-unknown})"
  cat old_client.log
  rm -rf "$old_dir" "$data_dir" old_server.log old_client.log "$stop2"
  if [ -n "$protocol" ] && [ "$protocol" -lt 17 ]; then
    echo "Old client check skipped: $tag predates the JSON handshake"
    return 0
  fi
  if [ "$refused" -ne 1 ]; then
    echo "::error::Old client $tag was not refused with WRONG_VERSION within 15 s"
    return 1
  fi
  echo "Old client $tag was refused with WRONG_VERSION"
}

echo "::group::Old release client is refused"
old_client_check || fail=1
echo "::endgroup::"

rm -f client.log server.log join.log "$stop"

echo "::group::Client build as a server (launcher Host a server)"
stop="$(mktemp -u)"
linux/ExperimentUndead.x86_64 --headless -- --server --port=7790 --max-players=4 "--stop-file=$stop" > host.log 2>&1 &
pid=$!
for _ in $(seq 1 60); do
  grep -q "Server ready" host.log && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done
if grep -q "Server ready" host.log; then
  timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 900 -- --join=127.0.0.1:7790 > hostjoin.log 2>&1
fi
touch "$stop"
timeout 15 tail --pid="$pid" -f /dev/null || kill -9 "$pid" 2>/dev/null
wait "$pid"
host_code=$?
cat host.log
echo "::endgroup::"
if ! grep -q "Server ready" host.log || ! grep -q "Player connected" host.log; then
  echo "::error::The client build started with --server did not open its port or accept a join"
  fail=1
fi
if [ "$host_code" -ne 0 ] || ! grep -q "Server stopped" host.log || grep -qE "$errors" host.log hostjoin.log 2>/dev/null; then
  echo "::error::The client build as a server did not stop cleanly on its stop file (exit $host_code)"
  fail=1
fi
rm -f host.log hostjoin.log "$stop"

echo "::group::Launcher installs a newer version and refreshes the root copy"
if ! "$(git rev-parse --show-toplevel)/tools/ci/launcher_e2e.sh" .; then
  fail=1
fi
echo "::endgroup::"
exit "$fail"
