#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME=Machlif
APP=".build/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo "1.0")
DMG=".build/${APP_NAME}-${VERSION}.dmg"
TMP=$(mktemp -d)

if [ ! -d "$APP" ]; then
    echo "error: $APP not found — run 'make app' first" >&2
    exit 1
fi

cp -R "$APP" "$TMP/"
ln -s /Applications "$TMP/Applications"

hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$TMP" \
    -ov \
    -format UDZO \
    "$DMG" > /dev/null

rm -rf "$TMP"
echo "Created $DMG"
