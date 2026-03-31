#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/RunRat.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAME_SOURCE_PATH="$ROOT_DIR/art/rat_frames_clean"
FRAMES_DIR="$ROOT_DIR/Sources/RunRat/Resources/Frames"
PREVIEW_PATH="$ROOT_DIR/tmp-frame-previews/final_menu_strip.png"
MANIFEST_PATH="$ROOT_DIR/Sources/RunRat/Resources/rat_frame_manifest.txt"

cd "$ROOT_DIR"
swift scripts/build-rat-frames.swift "$FRAME_SOURCE_PATH" "$FRAMES_DIR" "$PREVIEW_PATH"

find "$ROOT_DIR/.build" -type d -name 'RunRat_RunRat.bundle' -prune -exec rm -rf {} +

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
mkdir -p "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/RunRat"
chmod +x "$MACOS_DIR/RunRat"

find "$(dirname "$BINARY_PATH")" -maxdepth 1 -type d -name '*.bundle' -exec cp -R {} "$RESOURCES_DIR/" \;

if [[ -f "$MANIFEST_PATH" ]]; then
    FRAME_COUNT="$(tr -d '[:space:]' < "$MANIFEST_PATH")"
    if [[ "$FRAME_COUNT" =~ ^[0-9]+$ ]]; then
        while IFS= read -r frame_path; do
            frame_name="$(basename "$frame_path")"
            frame_index="${frame_name#rat_frame_}"
            frame_index="${frame_index%.png}"
            if [[ "$frame_index" =~ ^[0-9]+$ ]] && (( frame_index >= FRAME_COUNT )); then
                rm -f "$frame_path"
            fi
        done < <(find "$RESOURCES_DIR" -path '*/RunRat_RunRat.bundle/rat_frame_*.png' -type f | sort)
    fi
fi

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
