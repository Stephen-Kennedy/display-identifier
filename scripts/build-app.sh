#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Display Identifier"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/display-identify"
APP_VERSION="$(awk -F'"' '/let appVersion/ { print $2; exit }' "$ROOT_DIR/Sources/DisplayIdentifier/main.swift")"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cp "$ROOT_DIR/.build/release/display-identify" "$EXECUTABLE"
chmod +x "$EXECUTABLE"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>display-identify</string>
  <key>CFBundleIdentifier</key>
  <string>local.accord.display-identifier</string>
  <key>CFBundleName</key>
  <string>Display Identifier</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>APP_VERSION_PLACEHOLDER</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

perl -0pi -e "s/APP_VERSION_PLACEHOLDER/$APP_VERSION/g" "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
