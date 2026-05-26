#!/usr/bin/env bash
# Build Tally.app and package as both .zip and .dmg in build/.
# Use this for local release dry-runs; CI runs the same steps on tag push.
#
# Usage:
#   VERSION=0.1.0 ./Scripts/dist.sh    # explicit version
#   ./Scripts/dist.sh                  # reads CFBundleShortVersionString from Info.plist
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${VERSION:-}" ]]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
fi
echo "==> Packaging Tally v$VERSION"

CONFIG=release ./Scripts/bundle.sh

plutil -replace CFBundleShortVersionString -string "$VERSION" build/Tally.app/Contents/Info.plist
plutil -replace CFBundleVersion              -string "$VERSION" build/Tally.app/Contents/Info.plist
codesign --force --deep --sign - build/Tally.app >/dev/null 2>&1 || true

ZIP="build/Tally-$VERSION.zip"
DMG="build/Tally-$VERSION.dmg"
rm -f "$ZIP" "$DMG"

echo "==> Writing $ZIP"
ditto -c -k --sequesterRsrc --keepParent build/Tally.app "$ZIP"

echo "==> Writing $DMG"
hdiutil create -volname Tally -srcfolder build/Tally.app -ov -format UDZO "$DMG" >/dev/null

echo "==> Done:"
ls -lh "$ZIP" "$DMG"
