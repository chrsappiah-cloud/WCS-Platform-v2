#!/usr/bin/env bash
# Verifies the deployed lesson video Edge Function is configured for live OpenAI/Sora rendering.
#
# Usage:
#   SUPABASE_ANON_OR_PUBLISHABLE_KEY=sb_publishable_... \
#     ./scripts/preflight-live-lesson-video-backend.sh qbmheroqblpcbuqwnzlp
#
set -euo pipefail

REF="${1:-${SUPABASE_PROJECT_REF:-qbmheroqblpcbuqwnzlp}}"
KEY="${SUPABASE_ANON_OR_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-sb_publishable_VmBFsAln9J7F6ot30XsyAA_9i3OlTmh}}"
ENDPOINT="https://${REF}.supabase.co/functions/v1/wcs-lesson-text-to-video"

BODY='{
  "courseId": "preflight-course",
  "lessonId": "preflight-lesson",
  "textToVideoPrompt": "Generate a concise instructional video lesson.",
  "style": "instructional",
  "providerBackendHint": "sora",
  "sourceScript": "Teach three clinical communication phrases with definitions and examples."
}'

response="$(
  curl -sS -w '\n%{http_code}' -X POST "$ENDPOINT" \
    -H 'content-type: application/json' \
    -H "apikey: $KEY" \
    -H "authorization: Bearer $KEY" \
    --data "$BODY"
)"

http_status="$(printf '%s' "$response" | tail -n 1)"
json_body="$(printf '%s' "$response" | sed '$d')"

printf 'HTTP %s\n%s\n' "$http_status" "$json_body"

if [[ "$http_status" == "502" && "$json_body" == *"OPENAI_API_KEY not set"* ]]; then
  echo "Live backend is not ready: set OPENAI_API_KEY and VIDEO_PROVIDER=sora in Supabase secrets." >&2
  exit 2
fi

if [[ "$http_status" -lt 200 || "$http_status" -gt 299 ]]; then
  echo "Live backend preflight failed." >&2
  exit 1
fi

if [[ "$json_body" != *"playbackURL"* && "$json_body" != *"playbackUrl"* && "$json_body" != *"videoURL"* ]]; then
  echo "Live backend did not return a generated video URL." >&2
  exit 1
fi

echo "Live backend returned a generated video URL."
