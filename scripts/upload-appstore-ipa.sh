#!/usr/bin/env bash
# Upload WCS-Platform.ipa to App Store Connect (requires API key or app-specific password).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA="${IPA_PATH:-$REPO_ROOT/build/AppStoreExport/WCS-Platform.ipa}"

if [[ ! -f "$IPA" ]]; then
  echo "error: IPA not found at $IPA — run: bash scripts/archive-appstore.sh" >&2
  exit 1
fi

echo "IPA: $IPA ($(du -h "$IPA" | cut -f1))"

if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" && -n "${ASC_API_PRIVATE_KEY_PATH:-}" ]]; then
  echo "==> Uploading via altool (API key)"
  xcrun altool --upload-app \
    -f "$IPA" \
    -t ios \
    --apiKey "$ASC_API_KEY_ID" \
    --apiIssuer "$ASC_API_ISSUER_ID" \
    --apiKeyPath "$ASC_API_PRIVATE_KEY_PATH"
  echo "Upload submitted. Check App Store Connect → TestFlight / Activity for processing."
  exit 0
fi

if [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "==> Uploading via altool (Apple ID + app-specific password)"
  xcrun altool --upload-app \
    -f "$IPA" \
    -t ios \
    -u "$APPLE_ID" \
    -p "$APP_SPECIFIC_PASSWORD"
  echo "Upload submitted."
  exit 0
fi

echo "No upload credentials in environment."
echo "Set one of:"
echo "  ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_PRIVATE_KEY_PATH"
echo "  APPLE_ID, APP_SPECIFIC_PASSWORD"
echo ""
echo "Or upload manually:"
echo "  1. Open Transporter.app"
echo "  2. Deliver: $IPA"
echo "  3. App Store Connect → your app → version 1.0 → select build 10 → Submit for Review"
open -a Transporter "$IPA" 2>/dev/null || open -R "$IPA"
exit 2
