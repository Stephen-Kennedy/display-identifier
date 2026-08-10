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

Small click-through badges appear near the upper-left corner of every display.
They close automatically after 60 seconds. Use `--persist` to keep them visible
until you quit them.

While the badges are visible, a `Displays` menu appears in the macOS menu bar.
Use it to adjust opacity, open settings, show or hide badges, refresh displays,
or quit the overlay cleanly. The Settings window activates the utility and comes
forward over other apps when selected from the menu bar.

If the menu only shows `Opacity` and `Quit`, an older background copy is still
running. Pull the latest version and restart it:

```sh
git pull
scripts/stop.sh
scripts/launch-persistent.sh --opacity 0.20
```

`scripts/stop.sh` stops older copies launched through the persistent launcher,
`swift run display-identify`, or the double-clickable app bundle.

The current menu starts with `Display Identifier 1.1.0`, followed by
`Settings...`, `Show Badges`, `Hide Badges`, and `Refresh Displays`.

Each badge shows the macOS display number plus the display's physical position
relative to the main display. For example, `1 CENTER`, `2 RIGHT`, and `3 LEFT`
means macOS reports display 1 first, while the right/left labels show how the
screens are arranged in space.

## Run Without Holding The Terminal

For a persistent overlay that returns control to your shell:

```sh
chmod +x scripts/launch-persistent.sh
scripts/launch-persistent.sh
```

The launcher stops any older Display Identifier copy before starting the freshly
built one.

Quit from the `Displays` menu bar item, or run:

```sh
chmod +x scripts/stop.sh
scripts/stop.sh
```

## Options

```sh
swift run display-identify --duration 20
swift run display-identify --persist
swift run display-identify --persist --opacity 0.20
swift run display-identify --list
swift run display-identify --sort-geometry
swift run display-identify --center
```

Default numbering follows `NSScreen.screens`, which is the order macOS reports
to apps. `--sort-geometry` numbers screens left-to-right, then top-to-bottom.
`--list` prints the displays the app can see and exits. `--center` uses the
original large centered overlay style. `--opacity` accepts values from `0.08`
to `0.90`; lower values are more transparent.

## Future GUI Direction

The app now has a basic menu bar control and Settings window. A future polish
pass could make this a packaged login item with saved preferences, a custom menu
bar icon, and a normal macOS Preferences panel.

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
