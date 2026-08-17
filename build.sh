#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CruftX"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
ICONSET="$BUILD_DIR/AppIcon.iconset"
ARCH="$(uname -m)"

if [[ "$ARCH" == "arm64" ]]; then
  TARGET="arm64-apple-macosx13.0"
else
  TARGET="x86_64-apple-macosx13.0"
fi

# Prefer the SDK matching this compiler (macOS 26.0); fall back to default.
if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
else
  SDK="$(xcrun --show-sdk-path)"
fi

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"

echo "==> Compiling Swift sources"
swiftc -O -target "$TARGET" -swift-version 6 \
  -sdk "$SDK" \
  -module-cache-path "$BUILD_DIR/ModuleCache" \
  "$ROOT"/Sources/**/*.swift \
  -o "$APP/Contents/MacOS/$APP_NAME"

echo "==> Copying Info.plist"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> Generating app icon"
swift -sdk "$SDK" -module-cache-path "$BUILD_DIR/ModuleCache" \
  "$ROOT/Tools/gen_icon.swift" "$ICONSET" "$BUILD_DIR/AppIcon_Preview.png"
python3 "$ROOT/Tools/make_icns.py" "$ICONSET" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc signing"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Packaging"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/$APP_NAME.zip"

echo "==> Done: $APP"
echo "==> Archive: $BUILD_DIR/$APP_NAME.zip"
