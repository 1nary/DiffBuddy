#!/usr/bin/env bash
#
# DiffBuddy release script
#
# Usage:
#   ./scripts/release.sh appstore         # Archive + upload to App Store Connect
#   ./scripts/release.sh developerid      # Archive + notarize + staple + .dmg
#   ./scripts/release.sh both             # Both of the above
#
# Prerequisites:
#   - xcodegen installed (brew install xcodegen)
#   - DiffBuddy.xcodeproj generated (run: xcodegen)
#   - notarytool keychain profile stored under the name "AC_NOTARY"
#       xcrun notarytool store-credentials AC_NOTARY \
#         --apple-id "<your apple id>" \
#         --team-id  "H854PP94F8" \
#         --password "<app-specific password>"
#
set -euo pipefail

SCHEME="DiffBuddy"
PROJECT="DiffBuddy.xcodeproj"
BUILD_DIR="build"
ARCHIVE_APPSTORE="${BUILD_DIR}/DiffBuddy-AppStore.xcarchive"
ARCHIVE_DEVID="${BUILD_DIR}/DiffBuddy-DeveloperID.xcarchive"
EXPORT_APPSTORE="${BUILD_DIR}/export-appstore"
EXPORT_DEVID="${BUILD_DIR}/export-developerid"
NOTARY_PROFILE="AC_NOTARY"

mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "usage: $0 {appstore|developerid|both}" >&2
  exit 1
fi

ensure_project() {
  if [[ ! -d "$PROJECT" ]]; then
    echo "==> $PROJECT not found, running xcodegen"
    xcodegen
  fi
}

archive() {
  local config="$1" archive_path="$2"
  echo "==> Archiving ($config) -> $archive_path"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$config" \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    clean archive
}

export_archive() {
  local archive_path="$1" export_path="$2" options="$3"
  echo "==> Exporting -> $export_path"
  rm -rf "$export_path"
  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$options"
}

do_appstore() {
  ensure_project
  archive "Release" "$ARCHIVE_APPSTORE"

  : "${ASC_KEY_ID:?ASC_KEY_ID env var required}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID env var required}"
  : "${ASC_KEY_PATH:?ASC_KEY_PATH env var required}"

  echo "==> Exporting + uploading to App Store Connect"
  rm -rf "$EXPORT_APPSTORE"
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_APPSTORE" \
    -exportPath "$EXPORT_APPSTORE" \
    -exportOptionsPlist "ExportOptions-AppStore.plist" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyPath "$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)/$(basename "$ASC_KEY_PATH")"

  echo "==> App Store upload submitted."
}

do_developerid() {
  ensure_project
  archive "Release" "$ARCHIVE_DEVID"
  export_archive "$ARCHIVE_DEVID" "$EXPORT_DEVID" "ExportOptions-DeveloperID.plist"

  local app_path="${EXPORT_DEVID}/DiffBuddy.app"
  local zip_path="${BUILD_DIR}/DiffBuddy.zip"
  local dmg_path="${BUILD_DIR}/DiffBuddy.dmg"

  echo "==> Zipping for notarization"
  ditto -c -k --keepParent "$app_path" "$zip_path"

  echo "==> Submitting to notary service"
  xcrun notarytool submit "$zip_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "==> Stapling"
  xcrun stapler staple "$app_path"

  echo "==> Creating .dmg"
  rm -f "$dmg_path"
  hdiutil create \
    -volname "DiffBuddy" \
    -srcfolder "$app_path" \
    -ov -format ULFO \
    "$dmg_path"

  echo "==> Notarizing .dmg"
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "==> Stapling .dmg"
  xcrun stapler staple "$dmg_path"

  echo
  echo "Artifact: $dmg_path"
  echo "sha256:"
  shasum -a 256 "$dmg_path"
}

case "$mode" in
  appstore)    do_appstore ;;
  developerid) do_developerid ;;
  both)        do_appstore; do_developerid ;;
  *)
    echo "usage: $0 {appstore|developerid|both}" >&2
    exit 1
    ;;
esac
