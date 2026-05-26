#!/usr/bin/env bash
# Generate Resources/AppIcon.icns from Scripts/make-icon.swift.
# Run this whenever you change the icon design.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="build/AppIcon-1024.png"
ICONSET="build/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"

echo "==> Rendering 1024px source"
swift Scripts/make-icon.swift

echo "==> Building iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$SRC" "$ICONSET/icon_512x512@2x.png"

echo "==> Compiling $ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

rm -rf "$ICONSET" "$SRC"

echo "==> Done: $ICNS"
ls -lh "$ICNS"
