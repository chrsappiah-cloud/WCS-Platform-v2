#!/usr/bin/env bash
# List recent lesson video render jobs via Supabase REST (service role) or Edge GET.
#
# Usage:
#   bash scripts/query-lesson-video-jobs.sh          # PostgREST (requires service role)
#   bash scripts/query-lesson-video-jobs.sh edge   # Edge function (requires anon + job secret)
#
set -euo pipefail

usage_rest() {
  cat >&2 <<'EOF'
Missing env for PostgREST mode. Set:

  export SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # Dashboard → Settings → API → service_role (never put in the iOS app)

Then:
  bash scripts/query-lesson-video-jobs.sh

Example (replace ref and key):
  export SUPABASE_URL="https://qbmheroqblpcbuqwnzlp.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="…service_role…"
  bash scripts/query-lesson-video-jobs.sh
EOF
}

usage_edge() {
  cat >&2 <<'EOF'
Missing env for Edge mode. Deploy `wcs-lesson-video-jobs` and set secret WCS_JOB_LIST_SECRET, then:

  export SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
  export SUPABASE_ANON_KEY="eyJ..."   # or sb_publishable_… (same as app apikey)
  export WCS_JOB_LIST_SECRET="your-long-random-secret"   # must match Edge secret

Then:
  bash scripts/query-lesson-video-jobs.sh edge

Requires `jq` on PATH for pretty JSON (install: brew install jq).
EOF
}

MODE="${1:-rest}"

pretty_json() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
    echo >&2 "(tip: install jq for formatted output: brew install jq)"
  fi
}

if [[ "$MODE" == "edge" ]]; then
  if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" || -z "${WCS_JOB_LIST_SECRET:-}" ]]; then
    usage_edge
    exit 1
  fi
  URL="${SUPABASE_URL%/}/functions/v1/wcs-lesson-video-jobs"
  echo "→ GET $URL" >&2
  curl -sS "$URL" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "x-wcs-job-list-secret: ${WCS_JOB_LIST_SECRET}" | pretty_json
  exit 0
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  usage_rest
  exit 1
fi

echo "→ GET ${SUPABASE_URL}/rest/v1/wcs_lesson_video_render_jobs?select=*&order=created_at.desc&limit=20" >&2
curl -sS "${SUPABASE_URL%/}/rest/v1/wcs_lesson_video_render_jobs?select=*&order=created_at.desc&limit=20" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Accept: application/json" | pretty_json
