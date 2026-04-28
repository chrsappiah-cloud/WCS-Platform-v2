#!/usr/bin/env bash
# One-shot: link → db push → secrets → deploy both Edge functions → smoke-test job list.
#
# Prerequisites:
#   cp scripts/env.supabase.local.example .env.supabase.local
#   # Fill SUPABASE_ACCESS_TOKEN, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_OR_PUBLISHABLE_KEY
#   # Set WCS_JOB_LIST_SECRET (or leave empty to auto-generate)
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env.supabase.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "  cp scripts/env.supabase.local.example .env.supabase.local" >&2
  echo "  # then edit with your Dashboard tokens/keys" >&2
  exit 1
fi

# shellcheck source=/dev/null
set -a
source "$ENV_FILE"
set +a

: "${SUPABASE_ACCESS_TOKEN:?Set SUPABASE_ACCESS_TOKEN in .env.supabase.local}"
: "${SUPABASE_PROJECT_REF:?Set SUPABASE_PROJECT_REF in .env.supabase.local}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY in .env.supabase.local}"
: "${SUPABASE_ANON_OR_PUBLISHABLE_KEY:?Set SUPABASE_ANON_OR_PUBLISHABLE_KEY in .env.supabase.local}"

export SUPABASE_ACCESS_TOKEN

if [[ -z "${WCS_JOB_LIST_SECRET:-}" ]]; then
  WCS_JOB_LIST_SECRET="$(openssl rand -hex 24)"
  echo "Generated WCS_JOB_LIST_SECRET (save this into Xcode → WCS_LESSON_VIDEO_JOB_LIST_SECRET):"
  echo "$WCS_JOB_LIST_SECRET"
  echo ""
fi

REF="$SUPABASE_PROJECT_REF"
SUPABASE_URL="https://${REF}.supabase.co"
export SUPABASE_URL

echo "→ supabase link --project-ref $REF"
supabase link --project-ref "$REF"

echo "→ supabase db push --project-ref $REF"
supabase db push --project-ref "$REF"

echo "→ supabase secrets set (WCS_JOB_LIST_SECRET + VIDEO_PROVIDER=mock)"
supabase secrets set --project-ref "$REF" \
  WCS_JOB_LIST_SECRET="$WCS_JOB_LIST_SECRET" \
  VIDEO_PROVIDER=mock

echo "→ supabase functions deploy wcs-lesson-text-to-video"
supabase functions deploy wcs-lesson-text-to-video --project-ref "$REF"

echo "→ supabase functions deploy wcs-lesson-video-jobs"
supabase functions deploy wcs-lesson-video-jobs --project-ref "$REF"

echo ""
echo "=== Smoke test: PostgREST job rows (service role) ==="
export SUPABASE_SERVICE_ROLE_KEY
bash "$ROOT/scripts/query-lesson-video-jobs.sh" || true

echo ""
echo "=== Smoke test: Edge job list ==="
export SUPABASE_ANON_KEY="$SUPABASE_ANON_OR_PUBLISHABLE_KEY"
export WCS_JOB_LIST_SECRET
bash "$ROOT/scripts/query-lesson-video-jobs.sh" edge || true

echo ""
echo "Next: set Xcode User-Defined WCS_LESSON_VIDEO_JOB_LIST_SECRET to the same value as WCS_JOB_LIST_SECRET above."
echo "      iOS admin → Refresh job list."
