#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_NAME="SpaceSnap"
APP_PATH="build/${APP_NAME}.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)

swift build "${BUILD_FLAGS[@]}"
BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/${APP_NAME}"

rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BIN_PATH}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_PATH}/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "${APP_PATH}/Contents/Resources/"

if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "${VERSION}" "${APP_PATH}/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-${VERSION}}" "${APP_PATH}/Contents/Info.plist"
fi

SIGN_FLAGS=(--force --options runtime --sign "${SIGN_IDENTITY}")
if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    SIGN_FLAGS+=(--timestamp)
fi
codesign "${SIGN_FLAGS[@]}" "${APP_PATH}"

echo "${APP_PATH}"

if [[ "${1:-}" == "--install" ]]; then
    osascript -e "tell application id \"dev.mettlive.SpaceSnap\" to quit" >/dev/null 2>&1 || true
    for _ in {1..50}; do pgrep -xq "${APP_NAME}" || break; sleep 0.1; done
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_PATH}" "/Applications/${APP_NAME}.app"
    if [[ "${SIGN_IDENTITY}" == "-" ]]; then
        tccutil reset Accessibility dev.mettlive.SpaceSnap >/dev/null 2>&1 || true
    fi
    open "/Applications/${APP_NAME}.app"
fi
