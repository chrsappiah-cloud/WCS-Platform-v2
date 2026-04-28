#!/bin/zsh
# setup-testflight-secrets.sh
#
# One-shot helper that exports the Apple Distribution identity from the login
# keychain, encodes all six TestFlight CD secrets, and pushes them to the
# GitHub repository via `gh secret set`.
#
# RUN THIS IN Terminal.app (NOT via the AI assistant shell), because keychain
# access requires either the system Allow dialog OR your Mac login password
# typed at the prompt.
#
# Usage:
#   bash scripts/setup-testflight-secrets.sh
#
# Required: gh CLI authenticated against chrsappiah-cloud/WCS-Platform-v2,
# python3, openssl, security CLI (all preinstalled on macOS).
#
# Will overwrite the following GitHub Actions secrets in the repo:
#   APPLE_DISTRIBUTION_CERT_P12_BASE64
#   APPLE_DISTRIBUTION_CERT_P12_PASSWORD
#   APPLE_PROVISIONING_PROFILE_BASE64
#   ASC_API_KEY_ID
#   ASC_API_ISSUER_ID
#   ASC_API_PRIVATE_KEY_BASE64

set -euo pipefail

REPO="${REPO:-chrsappiah-cloud/WCS-Platform-v2}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
PROFILE_PATH="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/d987ca04-29d8-481b-b6b4-b2249a0a7e5e.mobileprovision"
P8_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_KLH62AX56M.p8"
ASC_KEY_ID="KLH62AX56M"
ASC_ISSUER_ID="70c46c69-5d6d-438d-b300-31df2b93163a"
DIST_CERT_NAME="Apple Distribution: Christopher Appiah-Thompson"

OUT_DIR="$HOME/.wcs_release_secrets"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$PROFILE_PATH" ]; then
  echo "ERROR: provisioning profile not found at:"
  echo "  $PROFILE_PATH"
  exit 1
fi
if [ ! -f "$P8_PATH" ]; then
  echo "ERROR: ASC API key not found at:"
  echo "  $P8_PATH"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: 'gh' CLI not found. Install with: brew install gh"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

echo
echo "=== WCS-Platform TestFlight CD secret bootstrap ==="
echo "Repo:           $REPO"
echo "Profile:        $(basename "$PROFILE_PATH")"
echo "ASC key:        $ASC_KEY_ID"
echo "ASC issuer:     $ASC_ISSUER_ID"
echo "Cert identity:  $DIST_CERT_NAME"
echo

# 1) Login password — needed to unlock keychain non-interactively and to grant
#    apple-tool partition access so `security export` doesn't prompt.
echo -n "Enter your Mac login password (used only to unlock the login keychain locally): "
read -rs LOGIN_PWD
echo
if [ -z "${LOGIN_PWD:-}" ]; then
  echo "ERROR: empty login password"
  exit 1
fi

# 2) p12 export password
P12_PASS="${P12_PASS:-$(openssl rand -hex 16)}"

echo ">>> Unlocking login keychain..."
security unlock-keychain -p "$LOGIN_PWD" "$KEYCHAIN"
echo ">>> Granting apple-tool partition access (suppresses Allow dialogs)..."
security set-key-partition-list -S apple-tool:,apple: -s -k "$LOGIN_PWD" "$KEYCHAIN" >/dev/null

echo ">>> Exporting all code-signing identities from login keychain..."
ALL_P12="$WORK/all.p12"
security export -k "$KEYCHAIN" -t identities -f pkcs12 -P "$P12_PASS" -o "$ALL_P12"

echo ">>> Splitting and isolating the Apple Distribution identity..."
ALL_PEM="$WORK/all.pem"
openssl pkcs12 -in "$ALL_P12" -nodes -passin "pass:$P12_PASS" -out "$ALL_PEM" -legacy >/dev/null 2>&1 \
  || openssl pkcs12 -in "$ALL_P12" -nodes -passin "pass:$P12_PASS" -out "$ALL_PEM"

DIST_CRT="$WORK/dist.crt"
DIST_KEY="$WORK/dist.key"
python3 - "$ALL_PEM" "$DIST_CRT" "$DIST_KEY" <<'PY'
import re, sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text()
out_crt = pathlib.Path(sys.argv[2])
out_key = pathlib.Path(sys.argv[3])
bags = re.split(r"(?=Bag Attributes)", src)
target_keyid = None
cert = None
for b in bags:
    if "Apple Distribution" in b and "BEGIN CERTIFICATE" in b:
        m = re.search(r"localKeyID:\s*([0-9A-F ]+)", b)
        if m:
            target_keyid = re.sub(r"\s+", "", m.group(1))
        cert_m = re.search(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", b, re.S)
        if cert_m:
            cert = cert_m.group(0)
        break
key = None
for b in bags:
    m = re.search(r"localKeyID:\s*([0-9A-F ]+)", b)
    if not m:
        continue
    if target_keyid is not None and re.sub(r"\s+", "", m.group(1)) != target_keyid:
        continue
    key_m = re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", b, re.S)
    if key_m:
        key = key_m.group(0)
        break
if not cert or not key:
    raise SystemExit("Could not isolate Apple Distribution cert + key")
out_crt.write_text(cert + "\n")
out_key.write_text(key + "\n")
print(f"  isolated keyID={target_keyid}")
PY

echo ">>> Repackaging single-identity .p12..."
DIST_P12="$OUT_DIR/dist.p12"
openssl pkcs12 -export \
  -inkey "$DIST_KEY" \
  -in "$DIST_CRT" \
  -out "$DIST_P12" \
  -passout "pass:$P12_PASS" \
  -name "$DIST_CERT_NAME"
chmod 600 "$DIST_P12"

echo ">>> Encoding all secrets to base64..."
APPLE_DISTRIBUTION_CERT_P12_BASE64=$(base64 < "$DIST_P12" | tr -d '\n')
APPLE_PROVISIONING_PROFILE_BASE64=$(base64 < "$PROFILE_PATH" | tr -d '\n')
ASC_API_PRIVATE_KEY_BASE64=$(base64 < "$P8_PATH" | tr -d '\n')

echo "    cert b64:    ${#APPLE_DISTRIBUTION_CERT_P12_BASE64} chars"
echo "    profile b64: ${#APPLE_PROVISIONING_PROFILE_BASE64} chars"
echo "    p8 b64:      ${#ASC_API_PRIVATE_KEY_BASE64} chars"

echo
echo ">>> Pushing all 6 secrets to GitHub repo: $REPO"
gh secret set APPLE_DISTRIBUTION_CERT_P12_BASE64   --repo "$REPO" --body "$APPLE_DISTRIBUTION_CERT_P12_BASE64"
gh secret set APPLE_DISTRIBUTION_CERT_P12_PASSWORD --repo "$REPO" --body "$P12_PASS"
gh secret set APPLE_PROVISIONING_PROFILE_BASE64    --repo "$REPO" --body "$APPLE_PROVISIONING_PROFILE_BASE64"
gh secret set ASC_API_KEY_ID                       --repo "$REPO" --body "$ASC_KEY_ID"
gh secret set ASC_API_ISSUER_ID                    --repo "$REPO" --body "$ASC_ISSUER_ID"
gh secret set ASC_API_PRIVATE_KEY_BASE64           --repo "$REPO" --body "$ASC_API_PRIVATE_KEY_BASE64"

echo
echo "=== Done. Verifying with 'gh secret list': ==="
gh secret list --repo "$REPO"

echo
echo "Local artifacts kept (chmod 600) at: $OUT_DIR"
echo "  - dist.p12  (single-identity Apple Distribution)"
echo "Generated p12 password (saved as APPLE_DISTRIBUTION_CERT_P12_PASSWORD secret):"
echo "  $P12_PASS"
echo
echo "Trigger the TestFlight workflow with:"
echo "  git tag v1.1.0-rc1 && git push origin v1.1.0-rc1"
echo "  # OR: gh workflow run ios-release-testflight.yml --repo $REPO --ref main"
