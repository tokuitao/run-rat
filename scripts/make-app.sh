#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/RunRat.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c release

BINARY_PATH="$(
    find "$ROOT_DIR/.build" -path '*/release/RunRat' -type f | head -n 1
)"

if [[ -z "$BINARY_PATH" ]]; then
    echo "Could not find the release binary for RunRat." >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/RunRat"
chmod +x "$MACOS_DIR/RunRat"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>RunRat</string>
    <key>CFBundleExecutable</key>
    <string>RunRat</string>
    <key>CFBundleIdentifier</key>
    <string>dev.codex.runrat</string>
    <key>CFBundleName</key>
    <string>RunRat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
