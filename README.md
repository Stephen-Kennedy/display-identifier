# Display Identifier

Tiny macOS helper for showing a big display number on every connected screen.
It is useful when the MacBook, external monitors, and Sidecar/iPad displays
make it hard to tell which screen macOS is treating as which.

## Clone

```sh
git clone https://github.com/Stephen-Kennedy/display-identifier.git
cd display-identifier
swift run display-identify
```

## Run From Source

```sh
cd /Users/stephenkennedy/.openclaw/workspace/products/display-identifier
swift run display-identify
```

The overlays close automatically after 10 seconds. You can also press `Esc`,
press `q`, or click any overlay.

## Options

```sh
swift run display-identify --duration 20
swift run display-identify --persistent
swift run display-identify --sort-geometry
```

Default numbering follows `NSScreen.screens`, which is the order macOS reports
to apps. `--sort-geometry` numbers screens left-to-right, then top-to-bottom.

## Build

```sh
swift build -c release
.build/release/display-identify
```

## Build A Double-Clickable App

```sh
chmod +x scripts/build-app.sh
scripts/build-app.sh
open "dist/Display Identifier.app"
```
