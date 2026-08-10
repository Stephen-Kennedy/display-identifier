# Display Identifier

Display Identifier is a small macOS menu bar utility that shows numbered,
click-through badges on every connected display.

It is built for MacBook desks with external monitors, Sidecar/iPad displays, or
rotating screen layouts where it is easy to lose track of which display macOS is
treating as `1`, `2`, `3`, and where each screen sits physically.

Badges can show labels like:

```text
1 CENTER
2 RIGHT
3 LEFT
```

## Requirements

- macOS 13 or later
- Swift 6 toolchain / Xcode command line tools

## Clone

Keep the source somewhere stable, not in Downloads. A good default is:

```sh
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/Stephen-Kennedy/display-identifier.git
cd display-identifier
```

## Install For Regular Use

Build and install the app into `~/Applications`:

```sh
scripts/install-app.sh
open "$HOME/Applications/Display Identifier.app"
```

`~/Developer/display-identifier` is the source repo you update with `git pull`.
`~/Applications/Display Identifier.app` is the regular app you open.

To update later:

```sh
cd ~/Developer/display-identifier
git pull
scripts/install-app.sh
open "$HOME/Applications/Display Identifier.app"
```

## Run From Source

For a quick 60-second display check:

```sh
swift run display-identify
```

For persistent badges that stay up until you quit:

```sh
swift run display-identify --persist --opacity 0.20
```

## Run Without Holding Terminal

Start persistent mode in the background:

```sh
scripts/launch-persistent.sh --opacity 0.20
```

That script stops older running copies, rebuilds the release binary, and starts a
fresh background copy.

Stop it from Terminal:

```sh
scripts/stop.sh
```

Or quit from the `Displays` menu bar item.

## Menu Controls

While Display Identifier is running, macOS shows a `Displays` item in the menu
bar. It includes:

- `Settings...`
- `Show Badges`
- `Hide Badges`
- `Refresh Displays`
- opacity slider
- `Quit`

The Settings window comes forward over other apps when opened from the menu.
The badges themselves stay passive and click-through so they do not steal focus.

## Options

```sh
swift run display-identify --duration 20
swift run display-identify --persist
swift run display-identify --persist --opacity 0.20
swift run display-identify --list
swift run display-identify --sort-geometry
swift run display-identify --center
swift run display-identify --version
```

Options:

- `--duration <seconds>`: auto-close after this many seconds. Default: `60`.
- `--persist`: stay open until quit from the menu bar or `scripts/stop.sh`.
- `--persistent`: alias for `--persist`.
- `--opacity <0.08-0.90>`: badge background opacity. Lower is more transparent.
- `--alpha <0.08-0.90>`: alias for `--opacity`.
- `--list`: print detected displays and exit.
- `--sort-geometry`: number screens left-to-right, then top-to-bottom.
- `--center`: use the original large centered overlay style.
- `--version`: print the app version and exit.

Default numbering follows `NSScreen.screens`, which is the order macOS reports
to apps. Position labels such as `LEFT`, `CENTER`, and `RIGHT` are based on each
screen's geometry relative to the main display.

## Troubleshooting

If the menu is missing newer options, an older copy is probably still running:

```sh
scripts/stop.sh
scripts/launch-persistent.sh --opacity 0.20
```

If Display Identifier only shows one display, check what macOS is reporting:

```sh
swift run display-identify --list
```

If `--list` only prints one display, macOS is only exposing one display to the
app at that moment. Check System Settings > Displays and reconnect Sidecar or
external monitors.

## Build A Double-Clickable App

```sh
scripts/build-app.sh
open "dist/Display Identifier.app"
```

## Uninstall

```sh
scripts/uninstall-app.sh
```

This moves `~/Applications/Display Identifier.app` to the Trash when possible.

## Development

```sh
swift build -c release
.build/release/display-identify --help
.build/release/display-identify --version
```

## License

MIT License. See [LICENSE](LICENSE).
