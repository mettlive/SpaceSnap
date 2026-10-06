#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpaceSnap"
BUNDLE_ID="dev.mettlive.SpaceSnap"
DOWNLOAD_URL="https://github.com/mettlive/SpaceSnap/releases/latest/download/${APP_NAME}.zip"
INSTALL_DIR="/Applications"

fail() {
    echo "error: $1" >&2
    exit 1
}

version_at_least() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2" ]]
}

[[ "$(uname -s)" == "Darwin" ]] || fail "${APP_NAME} runs on macOS only"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Downloading ${APP_NAME}..."
curl -fsSL "${DOWNLOAD_URL}" -o "${WORK_DIR}/${APP_NAME}.zip"
ditto -x -k "${WORK_DIR}/${APP_NAME}.zip" "${WORK_DIR}"
[[ -d "${WORK_DIR}/${APP_NAME}.app" ]] || fail "downloaded archive does not contain ${APP_NAME}.app"

MINIMUM_MACOS="$(plutil -extract LSMinimumSystemVersion raw "${WORK_DIR}/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null)" \
    || fail "could not read the minimum macOS version from ${APP_NAME}.app"
version_at_least "$(sw_vers -productVersion)" "${MINIMUM_MACOS}" || fail "${APP_NAME} requires macOS ${MINIMUM_MACOS} or later"

if pgrep -xq "${APP_NAME}"; then
    echo "Quitting running ${APP_NAME}..."
    osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
    for _ in {1..50}; do pgrep -xq "${APP_NAME}" || break; sleep 0.1; done
fi

privileged() {
    if [[ -w "${INSTALL_DIR}" ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

echo "Installing to ${INSTALL_DIR}/${APP_NAME}.app..."
privileged rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
privileged ditto "${WORK_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/${APP_NAME}.app"
privileged xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

if codesign -dv "${INSTALL_DIR}/${APP_NAME}.app" 2>&1 | grep -q '^Signature=adhoc'; then
    tccutil reset Accessibility "${BUNDLE_ID}" >/dev/null 2>&1 || true
fi

open "${INSTALL_DIR}/${APP_NAME}.app"

cat <<EOF
${APP_NAME} is installed and running (look for the desktop number in the menu bar).

Grant Accessibility access when macOS asks:
  System Settings > Privacy & Security > Accessibility > ${APP_NAME}
EOF
