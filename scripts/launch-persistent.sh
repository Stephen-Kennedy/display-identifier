#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${TMPDIR:-/tmp}display-identifier.log"

cd "$ROOT_DIR"
swift build -c release >/dev/null

nohup "$ROOT_DIR/.build/release/display-identify" --persist "$@" >"$LOG_FILE" 2>&1 &
echo "Display Identifier running in the background. Log: $LOG_FILE"
