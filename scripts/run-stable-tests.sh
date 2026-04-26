#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/WCS-Platform"
PROJECT_PATH="$APP_DIR/WCS-Platform.xcodeproj"
SCHEME="WCS-Platform"
DESTINATION="platform=iOS Simulator,name=iPhone 17"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/build/DerivedData-WCS-Platform-tests}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

echo "==> xcodegen generate"
(cd "$APP_DIR" && xcodegen generate)

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: expected project at $PROJECT_PATH"
  exit 1
fi

echo "==> Resetting simulator state"
xcrun simctl shutdown all || true
xcrun simctl erase all

echo "==> Running full test suite"
echo "    project: $PROJECT_PATH"
echo "    scheme: $SCHEME"
echo "    destination: $DESTINATION"
echo "    derived data: $DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  test
