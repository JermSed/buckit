#!/usr/bin/env bash
# Build, Developer ID sign, notarize, and package Buckit with create-dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile name.}"

./scripts/build-app.sh

app="build/Buckit.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
arch=$(lipo -archs "$app/Contents/MacOS/Buckit" | tr ' ' '-')
release_dir="build/release"
created_dmg="$release_dir/Buckit.dmg"
release_dmg="$release_dir/Buckit-${version}-macos-${arch}.dmg"
mkdir -p "$release_dir"

codesign --force --options runtime --timestamp \
    --entitlements Assets/Buckit.entitlements \
    --sign "$CODE_SIGN_IDENTITY" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

if [[ -x .build/create-dmg/node_modules/.bin/create-dmg ]]; then
    create_dmg=.build/create-dmg/node_modules/.bin/create-dmg
else
    create_dmg=""
fi

if [[ -n "$create_dmg" ]]; then
    "$create_dmg" --identity="$CODE_SIGN_IDENTITY" --no-version-in-filename \
        --dmg-title Buckit --overwrite "$app" "$release_dir"
else
    npm exec --yes --package=create-dmg@8.1.0 -- create-dmg \
        --identity="$CODE_SIGN_IDENTITY" --no-version-in-filename \
        --dmg-title Buckit --overwrite "$app" "$release_dir"
fi
mv -f "$created_dmg" "$release_dmg"
codesign --verify --verbose=2 "$release_dmg"

xcrun notarytool submit "$release_dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$release_dmg"
xcrun stapler validate "$release_dmg"
shasum -a 256 "$release_dmg"
echo "Ready to upload: $release_dmg"
