#!/usr/bin/env bash

set -euo pipefail

# CI gate for externally configured links.
# Provide env vars via GitHub Actions secrets/vars as needed.

ALLOWLIST="${WCS_ALLOWED_EXTERNAL_HOSTS:-}"
TARGET_VARS=(
  SOCIAL_INSTAGRAM_URL
  SOCIAL_TIKTOK_URL
  SOCIAL_FACEBOOK_URL
  SOCIAL_X_URL
  SOCIAL_YOUTUBE_CHANNEL_URL
  SOCIAL_LINKEDIN_URL
  STRIPE_MEMBERSHIP_CHECKOUT_URL
  ADMIN_MERCHANT_DASHBOARD_URL
  APPLE_IAP_GUIDE_URL
)

python3 - <<'PY'
import os
import sys
from urllib.parse import urlparse

default_allowed = {
    "instagram.com","www.instagram.com",
    "tiktok.com","www.tiktok.com",
    "facebook.com","www.facebook.com",
    "x.com","www.x.com","twitter.com","www.twitter.com",
    "youtube.com","www.youtube.com","youtu.be",
    "linkedin.com","www.linkedin.com",
    "stripe.com","dashboard.stripe.com","checkout.stripe.com",
    "developer.apple.com"
}
custom = {
    h.strip().lower()
    for h in os.getenv("WCS_ALLOWED_EXTERNAL_HOSTS", "").split(",")
    if h.strip()
}
allowed = default_allowed | custom

targets = [
    "SOCIAL_INSTAGRAM_URL",
    "SOCIAL_TIKTOK_URL",
    "SOCIAL_FACEBOOK_URL",
    "SOCIAL_X_URL",
    "SOCIAL_YOUTUBE_CHANNEL_URL",
    "SOCIAL_LINKEDIN_URL",
    "STRIPE_MEMBERSHIP_CHECKOUT_URL",
    "ADMIN_MERCHANT_DASHBOARD_URL",
    "APPLE_IAP_GUIDE_URL",
]

errors = []
for key in targets:
    val = os.getenv(key, "").strip()
    if not val:
        continue
    parsed = urlparse(val)
    if parsed.scheme not in {"https", "http"}:
        errors.append(f"{key}: invalid scheme {parsed.scheme!r}")
        continue
    host = (parsed.hostname or "").lower()
    if host not in allowed:
        errors.append(f"{key}: host {host!r} not in allowlist")

if errors:
    for e in errors:
        print(e)
    sys.exit(1)

print("External link configuration validation passed.")
PY
