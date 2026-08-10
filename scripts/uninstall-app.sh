#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Identifier"
INSTALL_DIR="${DISPLAY_IDENTIFIER_INSTALL_DIR:-$HOME/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
TRASH_DIR="$HOME/.Trash"

"$ROOT_DIR/scripts/stop.sh" >/dev/null || true

if [[ -d "$TARGET_APP" ]]; then
  if [[ -d "$TRASH_DIR" ]]; then
    TRASHED_APP="$TRASH_DIR/$APP_NAME $(date +%Y%m%d-%H%M%S).app"
    mv "$TARGET_APP" "$TRASHED_APP"
    echo "Moved $TARGET_APP to Trash."
  else
    echo "Refusing to remove $TARGET_APP because $TRASH_DIR is unavailable." >&2
    exit 1
  fi
else
  echo "$TARGET_APP was not installed."
fi
