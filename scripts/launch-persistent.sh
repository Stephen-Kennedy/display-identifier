#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
LOG_FILE="$TMP_ROOT/display-identifier.log"
PID_FILE="$TMP_ROOT/display-identifier.pid"
APP_NAME="Display Identifier"
INSTALLED_APP="${DISPLAY_IDENTIFIER_INSTALL_DIR:-$HOME/Applications}/$APP_NAME.app"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/stop.sh" >/dev/null || true
"$ROOT_DIR/scripts/build-app.sh" >/dev/null

if [[ -d "$INSTALLED_APP" ]]; then
  APP_TO_OPEN="$INSTALLED_APP"
else
  APP_TO_OPEN="$DIST_APP"
fi

open -n "$APP_TO_OPEN" --args --persist "$@"
sleep 1

PID="$(pgrep -f "$APP_TO_OPEN/Contents/MacOS/display-identify" | head -n 1 || true)"
if [[ -n "$PID" ]]; then
  echo "$PID" >"$PID_FILE"
  echo "Display Identifier running in the background. PID: $PID. App: $APP_TO_OPEN"
else
  echo "Display Identifier launch requested. App: $APP_TO_OPEN"
fi
