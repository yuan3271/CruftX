#!/bin/zsh
set -euo pipefail

# Builds the release DMG (requires build/CruftX.app from ./build.sh).
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -x build/dmg-venv/bin/dmgbuild ]]; then
  echo "==> Installing dmgbuild into build/dmg-venv (first run only)"
  python3 -m venv build/dmg-venv
  build/dmg-venv/bin/pip install --cache-dir build/pip-cache dmgbuild
fi

if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
else
  SDK="$(xcrun --show-sdk-path)"
fi

echo "==> Generating DMG background"
swift -sdk "$SDK" -module-cache-path build/ModuleCache \
  Tools/make_dmg_bg.swift build/dmg-background.png

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
echo "==> Building CruftX-$VERSION.dmg"
build/dmg-venv/bin/dmgbuild -s Tools/dmg-settings.json CruftX "build/CruftX-$VERSION.dmg"

echo "==> Verifying"
hdiutil verify "build/CruftX-$VERSION.dmg" | tail -1
echo "==> Done: build/CruftX-$VERSION.dmg"
