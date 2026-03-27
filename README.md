# RunRat

RunRat is a tiny macOS menu bar app that shows a rat running faster as CPU usage goes up.

It is inspired by the playful idea behind RunCat, but this repository contains an original rat-themed implementation built with Swift, AppKit, and Swift Package Manager.

## Features

- Lives in the macOS menu bar
- Samples CPU usage once per second
- Animates a rat icon based on current system load
- Shows a simple CPU percentage and pace label in the menu
- Builds into a standalone `.app` bundle

## Requirements

- macOS 13 or later
- Swift 6.3 or later
- Xcode Command Line Tools or Xcode

## Development

Run the app directly from SwiftPM:

```bash
swift run
```

## Build

Create a local app bundle:

```bash
./scripts/make-app.sh
open dist/RunRat.app
```

The generated bundle will be placed at `dist/RunRat.app`.

## Project Structure

- `Sources/RunRat/` contains the menu bar app, CPU monitor, animation logic, and rat renderer
- `scripts/make-app.sh` builds a release binary and packages it as a macOS app bundle

## Notes

- The app is currently unsigned and not notarized
- This repository does not include assets or code copied from RunCat
- The visual is drawn programmatically with AppKit

## Contributing

Issues and pull requests are welcome.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## License

This project is available under the [MIT License](LICENSE).
