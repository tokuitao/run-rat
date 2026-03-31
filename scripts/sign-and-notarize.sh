#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/RunRat.app"
UPLOAD_ZIP_PATH="$ROOT_DIR/dist/RunRat-notary-upload.zip"
FINAL_ZIP_PATH="$ROOT_DIR/dist/RunRat-macOS.zip"
NOTARY_LOG_PATH="$ROOT_DIR/dist/notary-result.json"

SIGNING_IDENTITY="${RUNRAT_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${RUNRAT_NOTARY_PROFILE:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "Missing RUNRAT_SIGNING_IDENTITY." >&2
    echo "Example: export RUNRAT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'" >&2
    exit 1
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Missing RUNRAT_NOTARY_PROFILE." >&2
    echo "Example: export RUNRAT_NOTARY_PROFILE='runrat-notary'" >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null; then
    echo "Signing identity not found: $SIGNING_IDENTITY" >&2
    security find-identity -v -p codesigning >&2
    exit 1
fi

cd "$ROOT_DIR"
./scripts/make-app.sh

if [[ ! -d "$APP_PATH" ]]; then
    echo "App bundle not found at $APP_PATH" >&2
    exit 1
fi

while IFS= read -r bundle_path; do
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$bundle_path"
done < <(find "$APP_PATH/Contents/Resources" -type d -name '*.bundle' | sort)

codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

rm -f "$UPLOAD_ZIP_PATH" "$FINAL_ZIP_PATH" "$NOTARY_LOG_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$UPLOAD_ZIP_PATH"

xcrun notarytool submit "$UPLOAD_ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json | tee "$NOTARY_LOG_PATH"

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP_PATH"

echo "Signed app: $APP_PATH"
echo "Notarized zip: $FINAL_ZIP_PATH"
echo "Notary log: $NOTARY_LOG_PATH"
