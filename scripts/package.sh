#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_NAME="SpaceSnap"
APP_PATH="build/${APP_NAME}.app"
DMG_PATH="build/${APP_NAME}.dmg"
ZIP_PATH="build/${APP_NAME}.zip"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

[[ -d "${APP_PATH}" ]] || { echo "error: ${APP_PATH} not found, run scripts/bundle.sh first" >&2; exit 1; }

notarize() {
    local credentials=()
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        credentials=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE}")
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
        credentials=(--apple-id "${APPLE_ID}" --team-id "${APPLE_TEAM_ID}" --password "${APPLE_APP_PASSWORD}")
    else
        echo "error: Developer ID signing requires NOTARY_KEYCHAIN_PROFILE or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_PASSWORD" >&2
        exit 1
    fi
    xcrun notarytool submit "$1" "${credentials[@]}" --wait
}

STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT
cp -R "${APP_PATH}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

rm -f "${DMG_PATH}" "${ZIP_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING}" -fs HFS+ -format UDZO -ov "${DMG_PATH}" >/dev/null

if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
    notarize "${DMG_PATH}"
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler staple "${APP_PATH}"
fi

ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "${DMG_PATH}"
echo "${ZIP_PATH}"
