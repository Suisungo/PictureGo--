#!/bin/zsh
set -e

ROOT_DIR="${0:A:h}"
cd "$ROOT_DIR"

APP_DIR="$ROOT_DIR/outputs/PictureGo.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

# Compile directly with the system Swift toolchain so the build does not depend
# on user-level SwiftPM caches or network access.
MODULE_CACHE="/private/tmp/picturego-modulecache"
BUILD_DIR="/private/tmp/picturego-build"
mkdir -p "$MODULE_CACHE" "$BUILD_DIR"
swiftc -parse-as-library \
  "$ROOT_DIR/Sources/PictureGo/main.swift" \
  -o "$BUILD_DIR/PictureGo" \
  -framework SwiftUI \
  -framework AppKit \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -module-cache-path "$MODULE_CACHE"
cp "$BUILD_DIR/PictureGo" "$APP_DIR/Contents/MacOS/PictureGo"

# Build the same blue-purple photo-stack mark used inside the UI into a native
# macOS .icns bundle, then attach it to the application package.
ICONSET_DIR="$BUILD_DIR/PictureGo.iconset"
rm -rf "$ICONSET_DIR"
swiftc "$ROOT_DIR/Resources/make_icon.swift" \
  -o "$BUILD_DIR/make_picturego_icon" \
  -framework AppKit \
  -framework ImageIO \
  -module-cache-path "$MODULE_CACHE"
"$BUILD_DIR/make_picturego_icon" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/PictureGo"

# Ad-hoc signing keeps the local app launchable without requiring a developer
# certificate or an internet connection.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built $APP_DIR"
