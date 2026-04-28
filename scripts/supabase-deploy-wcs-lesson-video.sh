#!/usr/bin/env bash
# Link this repo to a Supabase project, deploy the lesson text-to-video Edge Function,
# and print the plist/xcconfig line for WCSLessonTextToVideoEndpoint.
#
# Prerequisites: `supabase login` (Dashboard → Account → Access Tokens) on this machine.
#
# Usage:
#   ./scripts/supabase-deploy-wcs-lesson-video.sh YOUR_PROJECT_REF
#   SUPABASE_PROJECT_REF=YOUR_PROJECT_REF ./scripts/supabase-deploy-wcs-lesson-video.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="${1:-${SUPABASE_PROJECT_REF:-}}"
if [[ -z "$REF" ]]; then
  echo "Error: missing project ref (the random id in https://REF.supabase.co)." >&2
  echo "Usage: $0 YOUR_PROJECT_REF" >&2
  echo "   or: SUPABASE_PROJECT_REF=YOUR_PROJECT_REF $0" >&2
  exit 1
fi

cd "$ROOT"
echo "→ supabase link --project-ref $REF"
supabase link --project-ref "$REF"

echo "→ supabase db push --project-ref $REF (Storage bucket + wcs_lesson_video_render_jobs)"
supabase db push --project-ref "$REF"

echo "→ supabase functions deploy wcs-lesson-text-to-video --project-ref $REF"
supabase functions deploy wcs-lesson-text-to-video --project-ref "$REF"

echo "→ supabase functions deploy wcs-lesson-video-jobs --project-ref $REF"
supabase functions deploy wcs-lesson-video-jobs --project-ref "$REF"

ENDPOINT="https://${REF}.supabase.co/functions/v1/wcs-lesson-text-to-video"
JOBS_URL="https://${REF}.supabase.co/functions/v1/wcs-lesson-video-jobs"
echo ""
echo "Deployed: $ENDPOINT"
echo "Job list GET: $JOBS_URL  (header x-wcs-job-list-secret + WCS_JOB_LIST_SECRET)"
echo ""
echo "1) Secrets (set only what you use; repeat --project-ref as needed):"
cat <<EOF
supabase secrets set --project-ref "$REF" VIDEO_PROVIDER=mock WCS_JOB_LIST_SECRET="choose-a-long-random-string"
# Match WCS_JOB_LIST_SECRET in iOS build setting WCS_LESSON_VIDEO_JOB_LIST_SECRET (same value) to enable admin job list.
# Optional providers, e.g.:
# supabase secrets set --project-ref "$REF" OPENAI_API_KEY=sk-... VIDEO_PROVIDER=sora
# supabase secrets set --project-ref "$REF" LUMA_API_KEY=luma_... VIDEO_PROVIDER=luma
# supabase secrets set --project-ref "$REF" LTX_API_KEY=... LTX_API_BASE_URL=https://... VIDEO_PROVIDER=ltx
# supabase secrets set --project-ref "$REF" SVD_WORKER_URL=https://gpu.example/run VIDEO_PROVIDER=svd
EOF
echo ""
echo "2) iOS — set build setting or xcconfig (see WCS-Platform/Info.plist):"
echo "   WCS_LESSON_TEXT_TO_VIDEO_ENDPOINT = $ENDPOINT"
echo ""
echo "3) Optional app headers: WCSLessonTextToVideoSupabaseAnonKey + user JWT in WCSLessonTextToVideoAPIKey when REQUIRE_AUTH=true."
