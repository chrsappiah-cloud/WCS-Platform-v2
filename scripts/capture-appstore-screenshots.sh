#!/usr/bin/env bash
# Capture simulator screenshots and generate App Store distribution PNGs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/WCS-Platform"

xcodegen generate >/dev/null

IPHONE_DEST="${WCS_SCREENSHOT_IPHONE_DEST:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
IPAD_DEST="${WCS_SCREENSHOT_IPAD_DEST:-platform=iOS Simulator,name=Scholars Gallery iPad 13}"

echo "==> iPhone captures ($IPHONE_DEST)"
xcodebuild test \
  -project "WCS-Platform.xcodeproj" \
  -scheme "WCS-Platform" \
  -destination "$IPHONE_DEST" \
  -only-testing:WCS-PlatformUITests/WCS_AppStoreScreenshotTests/testCaptureDistributionScreenshots \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || true

echo "==> iPad captures ($IPAD_DEST)"
xcodebuild test \
  -project "WCS-Platform.xcodeproj" \
  -scheme "WCS-Platform" \
  -destination "$IPAD_DEST" \
  -only-testing:WCS-PlatformUITests/WCS_AppStoreScreenshotTests/testCaptureDistributionScreenshots \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || true

echo "==> Generate App Store distribution PNGs"
python3 "$ROOT/scripts/generate-appstore-distribution-assets.py"

echo "Done. Upload files listed in production/apple/promotional/distribution-manifest.json"
