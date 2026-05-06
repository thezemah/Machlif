#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME=Machlif
APP=".build/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo "1.0")
DMG=".build/${APP_NAME}-${VERSION}.dmg"
MOUNT="/Volumes/$APP_NAME"
TMP=$(mktemp -d)

cleanup() {
    hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

[ -d "$APP" ] || { echo "error: $APP not found — run 'make app' first" >&2; exit 1; }

# ── 1. Generate background image via Swift/AppKit ─────────────────────────────
echo "  Generating artwork…"
cat > "$TMP/bg.swift" << 'SWIFT'
import AppKit

let W: CGFloat = 540, H: CGFloat = 340

// Render at @2x then let sips downscale for crisp Retina
let scale: Int = 2
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// ── Background gradient ──────────────────────────────────────────────────────
NSGradient(
    colors: [NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1),
             NSColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1)],
    atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 270)

// ── Bottom bar ───────────────────────────────────────────────────────────────
let barH: CGFloat = 46
NSColor(red: 0.81, green: 0.83, blue: 0.86, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: barH)).fill()
NSColor(red: 0.68, green: 0.71, blue: 0.74, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: barH, width: W, height: 0.5)).fill()

// ── Arrow (icons sit at y=180 from top → y = H−180 = 160 in AppKit coords) ──
let iconY: CGFloat = H - 180   // 160 from bottom
let arrowPara = NSMutableParagraphStyle(); arrowPara.alignment = .center
NSAttributedString(string: "→", attributes: [
    .font: NSFont.systemFont(ofSize: 32, weight: .ultraLight),
    .foregroundColor: NSColor(red: 0.50, green: 0.55, blue: 0.62, alpha: 1),
    .paragraphStyle: arrowPara
]).draw(in: NSRect(x: 195, y: iconY - 20, width: 150, height: 40))

// ── Hint text ─────────────────────────────────────────────────────────────────
let hintPara = NSMutableParagraphStyle(); hintPara.alignment = .center
NSAttributedString(string: "Drag Machlif to Applications to install", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1),
    .paragraphStyle: hintPara
]).draw(in: NSRect(x: 0, y: 14, width: W, height: 18))

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [.interlaced: false])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

swift "$TMP/bg.swift" "$TMP/bg.png"

# ── 2. Staging folder ─────────────────────────────────────────────────────────
mkdir -p "$TMP/stage/.background"
cp -R "$APP" "$TMP/stage/$APP_NAME.app"
ln -s /Applications "$TMP/stage/Applications"
cp "$TMP/bg.png" "$TMP/stage/.background/bg.png"

# ── 3. Create + mount writable DMG ───────────────────────────────────────────
echo "  Staging…"
# Eject any stale volume with the same name to avoid naming conflicts
hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
sleep 1

hdiutil create -size 200m -fs HFS+ -volname "$APP_NAME" "$TMP/rw.dmg" > /dev/null
DEV=$(hdiutil attach "$TMP/rw.dmg" -noautoopen | awk 'NR==1{print $1}')

cp -R "$TMP/stage/." "$MOUNT/"

# ── 4. Style the Finder window ────────────────────────────────────────────────
echo "  Styling…"
sleep 2

# Convert POSIX path to alias before entering tell block (more reliable)
osascript << APPLESCRIPT
set bgAlias to (POSIX file "$MOUNT/.background/bg.png") as alias
tell application "Finder"
  tell disk "$APP_NAME"
    open
    delay 3
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 100, 740, 462}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 80
    set shows item info of opts to false
    set background picture of opts to bgAlias
    delay 2
    set position of item "$APP_NAME.app" of container window to {130, 180}
    set position of item "Applications" of container window to {410, 180}
    update without registering applications
    delay 6
    close
  end tell
end tell
APPLESCRIPT

# Poll until Finder flushes .DS_Store (up to 30 s)
echo "  Waiting for Finder to flush settings…"
for i in $(seq 1 30); do
    [ -f "$MOUNT/.DS_Store" ] && break
    sleep 1
done
sleep 2

# ── 5. Detach and convert to compressed read-only ─────────────────────────────
hdiutil detach "$DEV" -quiet
hdiutil convert "$TMP/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" > /dev/null

echo "Created $DMG"
