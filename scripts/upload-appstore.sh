#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA_PATH="${IPA_PATH:-$REPO_ROOT/build/AppStoreExport/WCS-Platform.ipa}"

ASC_API_KEY_ID="${ASC_API_KEY_ID:-}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-}"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "IPA not found at: $IPA_PATH"
  echo "Build/export first with: bash scripts/archive-appstore.sh"
  exit 1
fi

if [[ -z "$ASC_API_KEY_ID" || -z "$ASC_API_ISSUER_ID" ]]; then
  echo "Missing App Store Connect API credentials."
  echo "Set both environment variables:"
  echo "  ASC_API_KEY_ID=<your key id>"
  echo "  ASC_API_ISSUER_ID=<your issuer id>"
  echo
  echo "Then run:"
  echo "  ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... bash scripts/upload-appstore.sh"
  exit 1
fi

echo "Uploading IPA to App Store Connect..."
echo "IPA: $IPA_PATH"

xcrun altool \
  --upload-package "$IPA_PATH" \
  --api-key "$ASC_API_KEY_ID" \
  --api-issuer "$ASC_API_ISSUER_ID" \
  --show-progress

echo "Upload command submitted successfully."

APPLE_ID=""
ID_FILE="$REPO_ROOT/docs/AppStoreNumericAppleId.txt"
if [[ -f "$ID_FILE" ]]; then
  APPLE_ID="$(grep -E '^[0-9]+$' "$ID_FILE" | head -n1 || true)"
fi
if [[ -z "$APPLE_ID" ]]; then
  echo "Numeric Apple ID not found in docs/AppStoreNumericAppleId.txt"
  echo "Refresh it with: ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... bash scripts/fetch-appstore-apple-id.sh"
else
  echo "Numeric Apple ID (from docs): $APPLE_ID"
fi

echo "Check processing status in App Store Connect or run:"
if [[ -n "$APPLE_ID" ]]; then
  echo "  xcrun altool --build-status --apple-id $APPLE_ID --bundle-version <CURRENT_PROJECT_VERSION> --bundle-short-version-string <MARKETING_VERSION> --platform ios --api-key \"$ASC_API_KEY_ID\" --api-issuer \"$ASC_API_ISSUER_ID\""
else
  echo "  xcrun altool --build-status --apple-id <APP_ID> --bundle-version <CURRENT_PROJECT_VERSION> --bundle-short-version-string <MARKETING_VERSION> --platform ios --api-key \"$ASC_API_KEY_ID\" --api-issuer \"$ASC_API_ISSUER_ID\""
fi
