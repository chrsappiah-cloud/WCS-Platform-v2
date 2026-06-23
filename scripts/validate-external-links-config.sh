#!/usr/bin/env bash
set -euo pipefail

# Validates public social-link configuration for App Store review builds.

required_env_vars=(
  SOCIAL_INSTAGRAM_URL
  SOCIAL_TIKTOK_URL
  SOCIAL_FACEBOOK_URL
  SOCIAL_X_URL
  SOCIAL_YOUTUBE_CHANNEL_URL
  SOCIAL_LINKEDIN_URL
)

allowed_hosts=(
  "instagram.com" "www.instagram.com"
  "tiktok.com" "www.tiktok.com"
  "facebook.com" "www.facebook.com"
  "x.com" "www.x.com" "twitter.com" "www.twitter.com"
  "youtube.com" "www.youtube.com" "youtu.be"
  "linkedin.com" "www.linkedin.com"
)

status=0
for key in "${required_env_vars[@]}"; do
  value="${!key:-}"
  [[ -z "$value" ]] && continue
  host="$(python3 -c 'import sys, urllib.parse; print((urllib.parse.urlparse(sys.argv[1]).hostname or "").lower())' "$value")"
  if [[ -z "$host" ]]; then
    echo "Invalid URL for $key: $value" >&2
    status=1
    continue
  fi
  match=0
  for allowed in "${allowed_hosts[@]}"; do
    [[ "$host" == "$allowed" ]] && match=1 && break
  done
  if [[ "$match" -ne 1 ]]; then
    echo "Host not allowed for $key: $host" >&2
    status=1
  fi
done

exit "$status"
