# RunRat

RunRat is a tiny macOS menu bar app that shows a rat running faster as CPU usage goes up.

It is inspired by the playful idea behind RunCat, but this repository contains an original rat-themed implementation built with Swift, AppKit, and Swift Package Manager.

## Features

- Lives in the macOS menu bar
- Samples CPU usage once per second
- Animates a rat icon based on current system load
- Includes a fixed preview speed mode for motion tuning
- Shows a simple CPU percentage and pace label in the menu
- Builds into a standalone `.app` bundle

## Requirements

- macOS 13 or later
- Swift 6.3 or later
- Xcode Command Line Tools or Xcode

## Download

Download the latest `RunRat-macOS.zip` asset from [GitHub Releases](https://github.com/tokuitao/run-rat/releases), then extract `RunRat.app`.

Because the app is currently unsigned and not notarized, macOS may warn on first launch. If that happens:

1. Right-click `RunRat.app` and choose `Open`
2. Click `Open` again in the system dialog

If you prefer Terminal, you can also remove the quarantine flag manually:

```bash
xattr -dr com.apple.quarantine RunRat.app
```

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

## Maintainer Release Flow

Build a signed and notarized release zip with:

```bash
export RUNRAT_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export RUNRAT_NOTARY_PROFILE="runrat-notary"
./scripts/sign-and-notarize.sh
```

Before that, store notarization credentials once on the maintainer Mac:

```bash
xcrun notarytool store-credentials "runrat-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

After `scripts/sign-and-notarize.sh` finishes, upload the generated zip to the existing GitHub release:

```bash
gh release upload v0.1.0 dist/RunRat-macOS.zip --clobber
```

## Project Structure

- `Sources/RunRat/` contains the menu bar app, CPU monitor, animation logic, and rat renderer
- `scripts/make-app.sh` builds a release binary and packages it as a macOS app bundle
- `scripts/sign-and-notarize.sh` signs, notarizes, staples, and re-zips the app for distribution

## Notes

- The app is currently unsigned and not notarized
- Shipping a smooth double-click install experience requires a Developer ID Application certificate and Apple notarization credentials
- This repository does not include assets or code copied from RunCat
- The visual is played from bundled frame images

## Contributing

Issues and pull requests are welcome.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## License

This project is available under the [MIT License](LICENSE).
