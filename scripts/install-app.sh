#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Identifier"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="${DISPLAY_IDENTIFIER_INSTALL_DIR:-$HOME/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
TRASH_DIR="$HOME/.Trash"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/stop.sh" >/dev/null || true
"$ROOT_DIR/scripts/build-app.sh" >/dev/null

mkdir -p "$INSTALL_DIR"
if [[ -e "$TARGET_APP" ]]; then
  if [[ -d "$TRASH_DIR" ]]; then
    TRASHED_APP="$TRASH_DIR/$APP_NAME $(date +%Y%m%d-%H%M%S).app"
    mv "$TARGET_APP" "$TRASHED_APP"
  else
    echo "Refusing to overwrite $TARGET_APP because $TRASH_DIR is unavailable." >&2
    exit 1
  fi
fi

cp -R "$SOURCE_APP" "$TARGET_APP"

echo "Installed $APP_NAME to $TARGET_APP"
echo "Open it with:"
echo "  open \"$TARGET_APP\""
