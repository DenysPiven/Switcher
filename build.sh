#!/bin/zsh
# Builds build/Switcher.app
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/Switcher.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Switcher "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"
