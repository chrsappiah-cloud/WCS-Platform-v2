#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/WCS-Platform"
PROJECT_PATH="$APP_DIR/WCS-Platform.xcodeproj"
SCHEME="WCS-Platform"
CONFIGURATION="Release"
ARCHIVE_PATH="${ARCHIVE_PATH:-$REPO_ROOT/build/WCS-Platform-AppStore.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$REPO_ROOT/build/AppStoreExport}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$REPO_ROOT/scripts/ExportOptions-AppStore.plist}"
FALLBACK_EXPORT_OPTIONS_PLIST="${FALLBACK_EXPORT_OPTIONS_PLIST:-$REPO_ROOT/scripts/ExportOptions-AppStore-no-symbols.plist}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

echo "==> xcodegen generate"
(cd "$APP_DIR" && xcodegen generate)

echo "==> Archiving App Store build"
echo "Project: $PROJECT_PATH"
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "Archive path: $ARCHIVE_PATH"

mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  archive \
  -archivePath "$ARCHIVE_PATH"

echo "==> Exporting IPA (optional for CI/distribution)"
if [[ -f "$EXPORT_OPTIONS_PLIST" ]]; then
  set +e
  xcodebuild \
    -exportArchive \
    -allowProvisioningUpdates \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  primary_export_status=$?
  set -e

  if [[ $primary_export_status -ne 0 ]]; then
    if [[ -f "$FALLBACK_EXPORT_OPTIONS_PLIST" ]]; then
      echo "Primary export failed (status $primary_export_status). Retrying with no-symbols export options."
      xcodebuild \
        -exportArchive \
        -allowProvisioningUpdates \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$FALLBACK_EXPORT_OPTIONS_PLIST"
      echo "Export complete using fallback options: $EXPORT_PATH"
    else
      echo "Primary export failed and fallback options plist was not found: $FALLBACK_EXPORT_OPTIONS_PLIST"
      exit $primary_export_status
    fi
  else
    echo "Export complete: $EXPORT_PATH"
  fi
else
  echo "Export options plist not found at $EXPORT_OPTIONS_PLIST"
  echo "Skipping export. Archive is ready for Xcode Organizer upload."
fi

echo "Done."
