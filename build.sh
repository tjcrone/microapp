#!/bin/bash
set -euo pipefail

APP_NAME="MicroApp"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

echo "==> Building ${APP_NAME} (release)..."
swift build -c release

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "Sources/${APP_NAME}/Info.plist" "${CONTENTS}/Info.plist"

# Write PkgInfo
echo -n "APPL????" > "${CONTENTS}/PkgInfo"

echo "==> Code signing (ad-hoc)..."
codesign --force --sign - --entitlements /dev/stdin "${APP_BUNDLE}" <<ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "==> Done! Opening ${APP_BUNDLE}..."
open "${APP_BUNDLE}"
