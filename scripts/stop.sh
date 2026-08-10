#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${TMPDIR:-/tmp}display-identifier.pid"

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    echo "Stopped Display Identifier PID $PID."
    exit 0
  fi
  rm -f "$PID_FILE"
fi

if pkill -f "[d]isplay-identify.*--persist"; then
  echo "Stopped persistent Display Identifier process."
else
  echo "No persistent Display Identifier process found."
fi
