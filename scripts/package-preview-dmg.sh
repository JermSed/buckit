#!/usr/bin/env bash
# Build a local preview DMG with create-dmg. It is not signed for public release.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh
app="build/Buckit.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
arch=$(lipo -archs "$app/Contents/MacOS/Buckit" | tr ' ' '-')
release_dir="build/release"
mkdir -p "$release_dir"

if [[ -x .build/create-dmg/node_modules/.bin/create-dmg ]]; then
    .build/create-dmg/node_modules/.bin/create-dmg \
        --no-code-sign --no-version-in-filename --dmg-title Buckit \
        --overwrite "$app" "$release_dir"
else
    npm exec --yes --package=create-dmg@8.1.0 -- create-dmg \
        --no-code-sign --no-version-in-filename --dmg-title Buckit \
        --overwrite "$app" "$release_dir"
fi

preview_dmg="$release_dir/Buckit-${version}-macos-${arch}-PREVIEW.dmg"
mv -f "$release_dir/Buckit.dmg" "$preview_dmg"
hdiutil verify "$preview_dmg"
echo "Preview only: $preview_dmg"
