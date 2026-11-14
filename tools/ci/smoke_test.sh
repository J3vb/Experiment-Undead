#!/usr/bin/env bash
# Boots the exported Linux client and server headless and fails on script
# errors, or when the server never reports it is ready.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)/build"
fail=0

echo "::group::Client boot"
timeout 60 linux/ExperimentUndead.x86_64 --headless --quit-after 600 > client.log 2>&1
code=$?
cat client.log
echo "::endgroup::"
if [ "$code" -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" client.log; then
  echo "::error::Exported client failed to boot cleanly (exit $code)"
  fail=1
fi

echo "::group::Server boot"
stop="$(mktemp -u)"
EU_STOP_FILE="$stop" server/ExperimentUndead-server.x86_64 --headless > server.log 2>&1 &
pid=$!
for _ in $(seq 1 60); do
  grep -q "Server ready" server.log && break
  sleep 0.5
done
touch "$stop"
timeout 15 tail --pid="$pid" -f /dev/null
cat server.log
echo "::endgroup::"
if ! grep -q "Server ready" server.log || ! grep -q "Server stopped" server.log || grep -qE "SCRIPT ERROR|Parse Error" server.log; then
  echo "::error::Exported server did not start and stop cleanly"
  kill -9 "$pid" 2>/dev/null
  fail=1
fi

rm -f client.log server.log "$stop"
exit "$fail"
