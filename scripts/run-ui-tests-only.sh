#!/usr/bin/env bash
# Run XCTest UI target only (WCS-PlatformUITests). Does not erase simulators.
# Usage:
#   ./scripts/run-ui-tests-only.sh
#   ./scripts/run-ui-tests-only.sh 'platform=iOS Simulator,name=iPhone 17'
#
# Requires: brew install xcodegen

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/WCS-Platform"
PROJECT="$APP_DIR/WCS-Platform.xcodeproj"
DEST="${1:-platform=iOS Simulator,name=iPhone 17}"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData-WCS-Platform-ui-tests}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

echo "==> xcodegen generate"
(cd "$APP_DIR" && xcodegen generate)

echo "==> UI tests only"
echo "    project: $PROJECT"
echo "    destination: $DEST"

exec xcodebuild test \
  -project "$PROJECT" \
  -scheme WCS-Platform \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -parallel-testing-enabled NO \
  -only-testing:WCS-PlatformUITests
