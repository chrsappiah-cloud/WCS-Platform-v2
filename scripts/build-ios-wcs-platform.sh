#!/usr/bin/env bash
#
# Compile the WCS-Platform iOS app with xcodebuild (no archive).
#
# Why this script:
# - Using `platform=iOS Simulator,name=…` fails with xcodebuild exit 70 when
#   CoreSimulatorService is unavailable or that simulator name is not installed
#   (common in CI / remote agents). Default here is generic iOS device.
# - Override destination when you have a healthy Simulator:
#     WCS_XCODE_DESTINATION='platform=iOS Simulator,name=iPhone 17' ./scripts/build-ios-wcs-platform.sh
#   or: ./scripts/build-ios-wcs-platform.sh 'platform=iOS Simulator,name=iPhone 17'
# - List what Xcode sees: xcodebuild -project … -scheme WCS-Platform -showdestinations
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/WCS-Platform"
PROJECT_PATH="$APP_DIR/WCS-Platform.xcodeproj"
SCHEME="WCS-Platform"
DESTINATION="${1:-${WCS_XCODE_DESTINATION:-generic/platform=iOS}}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: expected Xcode project at $PROJECT_PATH" >&2
  exit 1
fi

echo "==> xcodebuild build"
echo "    project: $PROJECT_PATH"
echo "    scheme:  $SCHEME"
echo "    destination: $DESTINATION"

exec xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  build
