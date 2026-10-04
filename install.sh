#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpaceSnap"
BUNDLE_ID="dev.mettlive.SpaceSnap"
DOWNLOAD_URL="https://github.com/mettlive/SpaceSnap/releases/latest/download/${APP_NAME}.zip"
INSTALL_DIR="/Applications"
MINIMUM_MACOS="26.6"

fail() {
    echo "error: $1" >&2
    exit 1
}

version_at_least() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2" ]]
}

[[ "$(uname -s)" == "Darwin" ]] || fail "${APP_NAME} runs on macOS only"
version_at_least "$(sw_vers -productVersion)" "${MINIMUM_MACOS}" || fail "${APP_NAME} requires macOS ${MINIMUM_MACOS} or later"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Downloading ${APP_NAME}..."
curl -fsSL "${DOWNLOAD_URL}" -o "${WORK_DIR}/${APP_NAME}.zip"
ditto -x -k "${WORK_DIR}/${APP_NAME}.zip" "${WORK_DIR}"
[[ -d "${WORK_DIR}/${APP_NAME}.app" ]] || fail "downloaded archive does not contain ${APP_NAME}.app"

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

open "${INSTALL_DIR}/${APP_NAME}.app"

cat <<EOF
${APP_NAME} is installed and running (look for the desktop number in the menu bar).

Grant Accessibility access when prompted:
  System Settings > Privacy & Security > Accessibility > ${APP_NAME}
If ${APP_NAME} was already listed there from a previous version, remove it with "-" and enable it again.
EOF
