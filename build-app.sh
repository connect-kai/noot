#!/bin/sh
# Build Noot.app and install to ~/Applications
set -e
cd "$(dirname "$0")"
swift build -c release
APP="$HOME/Applications/Noot.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Noot "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force -s - "$APP"
echo "Installed $APP"
