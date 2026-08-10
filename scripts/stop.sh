#!/usr/bin/env bash
set -euo pipefail

TMP_ROOT="${TMPDIR:-/tmp}"
PID_FILE="$TMP_ROOT/display-identifier.pid"
STOPPED=0

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    STOPPED=$((STOPPED + 1))
    echo "Stopped Display Identifier PID $PID."
  fi
  rm -f "$PID_FILE"
fi

osascript -e 'tell application id "local.accord.display-identifier" to quit' >/dev/null 2>&1 || true

PIDS="$(
  {
    pgrep -f "[d]isplay-identify" || true
    pgrep -f "[s]wift.*display-identify" || true
  } | awk -v self="$$" '$1 != self { print }' | sort -u
)"

if [[ -n "$PIDS" ]]; then
  while IFS= read -r PID; do
    [[ -z "$PID" ]] && continue
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      STOPPED=$((STOPPED + 1))
      echo "Stopped Display Identifier PID $PID."
    fi
  done <<< "$PIDS"

  sleep 0.5

  while IFS= read -r PID; do
    [[ -z "$PID" ]] && continue
    if kill -0 "$PID" 2>/dev/null; then
      kill -KILL "$PID" 2>/dev/null || true
      echo "Force-stopped Display Identifier PID $PID."
    fi
  done <<< "$PIDS"
fi

if [[ "$STOPPED" -eq 0 ]]; then
  echo "No Display Identifier process found."
fi
