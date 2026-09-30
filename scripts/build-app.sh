#!/usr/bin/env bash
# Builds Buckit.app into ./build (release, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Buckit"

APP="build/Buckit.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Buckit"
cp Assets/Buckit.icns "$APP/Contents/Resources/Buckit.icns"
cp Assets/buckit-menu.png "$APP/Contents/Resources/buckit-menu.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Buckit</string>
    <key>CFBundleDisplayName</key><string>Buckit</string>
    <key>CFBundleIdentifier</key><string>com.jermsed.buckit</string>
    <key>CFBundleExecutable</key><string>Buckit</string>
    <key>CFBundleIconFile</key><string>Buckit</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Buckit reads your last active browser tab URL when you choose Add, so you can save it to a Space.</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
