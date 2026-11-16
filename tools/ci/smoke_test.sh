#!/usr/bin/env bash
# Boots the exported Linux client and server headless, joins the server with
# the exported client, then stops the server. Fails on script errors, crashes,
# non-zero exit codes, or a server that never becomes ready or never stops.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)/build"
fail=0
errors="SCRIPT ERROR|Parse Error"

echo "::group::Client boot"
timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 600 > client.log 2>&1
code=$?
cat client.log
echo "::endgroup::"
if [ "$code" -ne 0 ] || grep -qE "$errors" client.log; then
  echo "::error::Exported client failed to boot cleanly (exit $code)"
  fail=1
fi

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
if grep -q "Server ready" server.log; then
  timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 900 -- --join=127.0.0.1:7777 > join.log 2>&1
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

rm -f client.log server.log join.log "$stop"
exit "$fail"
