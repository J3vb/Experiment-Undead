#!/bin/sh
# Starts the server and turns SIGTERM (docker stop) into a clean quit:
# Godot ignores the signal, so we drop a stop file the server watches.
set -u

rm -f "$EU_STOP_FILE" "$EU_READY_FILE"

./ExperimentUndead-server.x86_64 --headless "$@" &
pid=$!

trap 'touch "$EU_STOP_FILE"' TERM INT
wait "$pid"
status=$?
# wait returns early (>128) when the trap fires; wait again for the real exit.
if [ "$status" -gt 128 ] && kill -0 "$pid" 2>/dev/null; then
  wait "$pid"
  status=$?
fi
exit "$status"
