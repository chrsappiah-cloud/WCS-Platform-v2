#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/WCS-Platform"
PROJECT_PATH="$APP_DIR/WCS-Platform.xcodeproj"
SCHEME="WCS-Platform"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/build/DerivedData-WCS-production-kit}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

echo "==> xcodegen generate"
(cd "$APP_DIR" && xcodegen generate)

echo "==> Layer 1-4: WCS-PlatformTests (models, view models, network, integration)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -enableCodeCoverage YES \
  -parallel-testing-enabled NO \
  -only-testing:"WCS-PlatformTests" \
  test

echo "==> Layer 5: UI smoke + review harness"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  -only-testing:"WCS-PlatformUITests/Smoke" \
  -only-testing:"WCS-PlatformUITests/ReviewFlows" \
  -only-testing:"WCS-PlatformUITests/Recovery" \
  -only-testing:"WCS-PlatformUITests/UI" \
  test

echo "==> Production test kit complete"
