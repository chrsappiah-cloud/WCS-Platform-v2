#!/usr/bin/env bash
# Fetches the numeric App Store Connect Apple ID for a bundle (for altool --build-status, etc.)
# Requires: ASC_API_KEY_ID, ASC_API_ISSUER_ID (same as upload-appstore.sh)
# Optional: ASC_APP_PROVIDER_PUBLIC_ID (default TM2WG7HH96), ASC_BUNDLE_ID (default wcs.WCS-Platform)
# Optional: APPSTORE_APPLE_ID_FILE=path to override output file
# Optional: COPY_TO_CLIPBOARD=1 to copy the ID to the clipboard on macOS (pbcopy)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVIDER="${ASC_APP_PROVIDER_PUBLIC_ID:-TM2WG7HH96}"
BUNDLE="${ASC_BUNDLE_ID:-wcs.WCS-Platform}"
KEY="${ASC_API_KEY_ID:-}"
ISSUER="${ASC_API_ISSUER_ID:-}"
OUT_FILE="${APPSTORE_APPLE_ID_FILE:-$REPO_ROOT/docs/AppStoreNumericAppleId.txt}"

if [[ -z "$KEY" || -z "$ISSUER" ]]; then
  echo "Missing App Store Connect API credentials." >&2
  echo "Set ASC_API_KEY_ID and ASC_API_ISSUER_ID (same as scripts/upload-appstore.sh)." >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

xcrun altool --list-apps \
  --provider-public-id "$PROVIDER" \
  --filter-bundle-id "$BUNDLE" \
  --api-key "$KEY" \
  --api-issuer "$ISSUER" \
  --output-format json 2>/dev/null >"$TMP"

APPLE_ID="$(
  python3 - "$TMP" "$BUNDLE" <<'PY'
import json, sys
path, want = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, list) or not data:
    sys.exit("altool returned no apps")
app = None
for item in data:
    if item.get("bundleId") == want:
        app = item
        break
if app is None:
    sys.exit(f"no app with bundleId {want!r}")
aid = app.get("id")
if aid is None:
    sys.exit("app record missing id")
print(aid)
PY
)"

{
  echo "# Numeric App Store Connect Apple ID (not Team ID)."
  echo "# Bundle ID: $BUNDLE"
  echo "# Provider (Team) public ID: $PROVIDER"
  echo "# Regenerate: ASC_API_KEY_ID=... ASC_API_ISSUER_ID=... bash scripts/fetch-appstore-apple-id.sh"
  echo "$APPLE_ID"
} >"$OUT_FILE"

echo "Saved numeric Apple ID to: $OUT_FILE"
echo "$APPLE_ID"

if [[ "${COPY_TO_CLIPBOARD:-}" == "1" ]] && command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$APPLE_ID" | pbcopy
  echo "Copied to clipboard (pbcopy)."
fi
