#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LidGuard"
PRODUCT_NAME="LidGuardGUI"
BUNDLE_ID="com.lidguard.app"
VERSION="${VERSION:-0.1.0}"
BUILD_DIR=".build/release"
DIST_DIR="dist"
TEMP_ROOT=".build/tmp"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
ICON_NAME="AppIcon.icns"
ICON_SOURCE=""
ICONSET_DIR=""
STAGING_DIR=""

required_commands=(swift sips iconutil hdiutil)
for cmd in "${required_commands[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Missing required command: ${cmd}" >&2
        exit 1
    fi
done

cleanup() {
    [ -n "${STAGING_DIR}" ] && rm -rf "${STAGING_DIR}"
    [ -n "${ICONSET_DIR}" ] && rm -rf "${ICONSET_DIR}"
    [ -n "${ICON_SOURCE}" ] && rm -f "${ICON_SOURCE}"
}
trap cleanup EXIT

rm -rf "${DIST_DIR}" ".build/AppIcon.iconset" ".build/dmg-staging"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources" "${TEMP_ROOT}"

STAGING_DIR="$(mktemp -d "${TEMP_ROOT}/dmg-staging.XXXXXX")"
ICONSET_DIR="${TEMP_ROOT}/AppIcon.iconset"
ICON_SOURCE="${TEMP_ROOT}/LidGuard-1024.png"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

swift build --product "${PRODUCT_NAME}" --configuration release --disable-sandbox

cp "${BUILD_DIR}/${PRODUCT_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

swift scripts/generate_icon.swift "${ICON_SOURCE}"

sips -z 16 16 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
cp "${ICON_SOURCE}" "${ICONSET_DIR}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/${ICON_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "${APP_DIR}"
fi

cp -R "${APP_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "Created ${DMG_PATH}"
