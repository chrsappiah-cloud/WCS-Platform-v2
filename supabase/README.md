# Supabase — WCS lesson text-to-video

This folder adds a **Supabase Edge Function** `wcs-lesson-text-to-video` that matches the iOS contract
(`RemoteLessonTextToVideoRequest` → JSON response `{ "playbackURL": "https://…", "message"?: "…" }`).

The iOS app may send **`pipelineMode`: `"scene_orchestration_v1"`** and a **`storyboard`** object (`scenes[]` with per-scene prompts and narration). The Edge function can ignore these today and keep using `textToVideoPrompt`, or evolve to **per-scene jobs + composition** without changing the client’s `playbackURL` contract.

**Keys:** use **`sb_publishable_…` (or legacy anon JWT)** only in the iOS app (`apikey` / optional Bearer for Edge). Never ship **`sb_secret_…`** or the **service role** key in the client or in Git — those bypass Row Level Security. Edge Functions already receive `SUPABASE_SERVICE_ROLE_KEY` from the platform at runtime; you do not paste your secret key into Xcode.

### URLs (project `qbmheroqblpcbuqwnzlp`)

| Surface | Base URL |
|---------|----------|
| **PostgREST** | `https://qbmheroqblpcbuqwnzlp.supabase.co/rest/v1/` |
| **Edge Functions** | `https://qbmheroqblpcbuqwnzlp.supabase.co/functions/v1/` |
| **Storage (API)** | `https://qbmheroqblpcbuqwnzlp.supabase.co/storage/v1/` |

`scripts/query-lesson-video-jobs.sh` uses `SUPABASE_URL` + `/rest/v1/wcs_lesson_video_render_jobs` (service role). Tables with `REVOKE` for `anon`/`authenticated` return empty/forbidden unless you use the **service role** key (server-side only).

## 1. Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) installed.
- A Supabase project. This repo’s `supabase/config.toml` uses ref **`qbmheroqblpcbuqwnzlp`** (`https://qbmheroqblpcbuqwnzlp.supabase.co`); forkers should replace with their own ref.
- **CI / headless / Cursor agents:** use a [personal access token](https://supabase.com/dashboard/account/tokens) as `SUPABASE_ACCESS_TOKEN` (CLI reads it automatically when set). Interactive `supabase login` is not available in every environment.

### One-shot bootstrap (your machine)

```bash
cd /Applications/WCS-Platform
cp scripts/env.supabase.local.example .env.supabase.local
# Edit .env.supabase.local: SUPABASE_ACCESS_TOKEN, keys, optional WCS_JOB_LIST_SECRET
bash scripts/supabase-bootstrap-lesson-video.sh
```

Then set **Xcode → `WCS_LESSON_VIDEO_JOB_LIST_SECRET`** to the same string as **`WCS_JOB_LIST_SECRET`** (printed or in your env file). Never commit `.env.supabase.local`.

## 2. Storage bucket

Apply the migration (creates private bucket `lesson-videos`):

```bash
cd /Applications/WCS-Platform
supabase db push
```

Or run the SQL in the Supabase SQL editor.

## 3. Secrets (Edge Function)

Set provider keys **only** on the server (Dashboard → **Project Settings → Edge Functions → Secrets**, or CLI):

```bash
supabase secrets set --project-ref YOUR_PROJECT_REF \
  OPENAI_API_KEY=sk-... \
  LUMA_API_KEY=luma_... \
  LTX_API_KEY=... \
  LTX_API_BASE_URL=https://api.ltx.video/v1 \
  SVD_WORKER_URL=https://your-gpu-worker.example/generate \
  VIDEO_PROVIDER=mock \
  WCS_JOB_LIST_SECRET="your-long-random-secret"
```

(`WCS_JOB_LIST_SECRET` is required for **`wcs-lesson-video-jobs`** and should match iOS **`WCS_LESSON_VIDEO_JOB_LIST_SECRET`**.)

- `VIDEO_PROVIDER`: `mock` | `sora` | `luma` | `ltx` | `svd`. The iOS app can override with `providerBackendHint` in the JSON body when non-empty.
- `REQUIRE_AUTH=true` optional — then the function requires a valid Supabase JWT on `Authorization: Bearer …` (user must be signed in).

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_ANON_KEY` are injected automatically for Edge Functions.

## 4. Link + deploy the function

From the repo root (requires `supabase login` first):

```bash
cd /Applications/WCS-Platform
chmod +x scripts/supabase-deploy-wcs-lesson-video.sh   # once
./scripts/supabase-deploy-wcs-lesson-video.sh YOUR_PROJECT_REF
```

Or manually:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --project-ref YOUR_PROJECT_REF
supabase functions deploy wcs-lesson-text-to-video --project-ref YOUR_PROJECT_REF
supabase functions deploy wcs-lesson-video-jobs --project-ref YOUR_PROJECT_REF
```

### Job audit list (`wcs-lesson-video-jobs`)

- **GET** `…/functions/v1/wcs-lesson-video-jobs` returns `{ "jobs": [ … ] }` (latest rows from `wcs_lesson_video_render_jobs`).
- Set Edge secret **`WCS_JOB_LIST_SECRET`**; callers send header **`x-wcs-job-list-secret`** with the same value (plus `apikey` / `Authorization` as for other Edge functions).
- iOS admin panel: set **`WCS_LESSON_VIDEO_JOB_LIST_SECRET`** (same value) to enable **Lesson video render audit**.
- Terminal: `bash scripts/query-lesson-video-jobs.sh` (PostgREST + service role) or `bash scripts/query-lesson-video-jobs.sh edge` (optional `jq` for pretty JSON).

### Quick test (after `supabase db push`)

**A — PostgREST (service role; ops only, never in the app)**

```bash
export SUPABASE_URL="https://qbmheroqblpcbuqwnzlp.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="…service_role…"
bash scripts/query-lesson-video-jobs.sh
```

**B — Edge `wcs-lesson-video-jobs` (same secret as iOS `WCS_LESSON_VIDEO_JOB_LIST_SECRET`)**

```bash
supabase secrets set --project-ref YOUR_PROJECT_REF WCS_JOB_LIST_SECRET="your-long-random-secret"
```

```bash
export SUPABASE_URL="https://qbmheroqblpcbuqwnzlp.supabase.co"
export SUPABASE_ANON_KEY="…anon or publishable…"
export WCS_JOB_LIST_SECRET="your-long-random-secret"
bash scripts/query-lesson-video-jobs.sh edge
```

**C — iOS admin**

1. Regenerate module videos (or any path that hits `wcs-lesson-text-to-video`).
2. Xcode → Build Settings → set **`WCS_LESSON_VIDEO_JOB_LIST_SECRET`** = same string as **`WCS_JOB_LIST_SECRET`** on the Edge function.
3. Open **WCS AI Course Generation** → **Refresh job list** under *Lesson video render audit*.

## 5. Configure the iOS app

The app target reads **`WCSLessonTextToVideoEndpoint`** from **Info.plist**, which is set to
`$(WCS_LESSON_TEXT_TO_VIDEO_ENDPOINT)` with a default **empty** string in Xcode so remote stays off until you configure it.

Set the build setting (xcconfig or Xcode → Build Settings → User-Defined) to your deployed URL:

`https://YOUR_PROJECT_REF.supabase.co/functions/v1/wcs-lesson-text-to-video`

See `scripts/video-generation.example.xcconfig`.

Optional: `WCSLessonTextToVideoAPIKey` — use a **function-specific secret** or the caller’s JWT; do **not** ship the Supabase **service role** key in the app.

For Supabase **anon** + user JWT flows, set `WCSLessonTextToVideoSupabaseAnonKey` to the project anon key and pass the user’s access token as `Authorization: Bearer` from the app when you wire auth.

## 6. Provider notes

| Provider | Behavior |
|----------|-----------|
| **mock** | Downloads a short public sample MP4, uploads to Storage, returns signed URL. No external keys. |
| **sora** | OpenAI `POST /v1/videos`, polls until `completed`, downloads `/content`. May hit Edge CPU/time limits for long jobs. |
| **luma** | `POST /dream-machine/v1/generations`, polls until `assets.video`. |
| **ltx** | `POST` to `LTX_API_BASE_URL` + `LTX_TEXT_TO_VIDEO_PATH` (default `/text-to-video`); supports JSON URL or raw video body. **Adjust** to your vendor’s real OpenAPI. |
| **svd** | `POST` to `SVD_WORKER_URL`; expects JSON with `playbackURL` / `playbackUrl` / `url` or raw `video/*` bytes. |

Production hardening: rate limits, content moderation, course ownership checks, and async jobs (queue + webhook) should be added before scaling traffic.

## 7. Single-region data + backups (implemented posture)

- **One region:** keep the Supabase project in a single region closest to learners and your compliance choice.
- **Canonical store:** **Postgres** (this project’s `wcs_lesson_video_render_jobs` + your app tables) and **Storage** bucket `lesson-videos` for MP4s.
- **Database backups:** enable **Supabase Dashboard → Database → Backups** (and **Point-in-Time Recovery** on paid tiers). Restore drills are your DR test.
- **Job audit:** migration `20260428140000_lesson_video_render_jobs.sql` creates `public.wcs_lesson_video_render_jobs`. The Edge function **inserts one row per request** (`completed` or `failed`) with `request_json`, optional `storyboard_json`, and `generation_prompt_excerpt`. Only **`service_role`** may read/write this table (anon/authenticated revoked).
- **Optional second copy of blobs (same region):** if you want an extra MP4 copy beyond Supabase Storage, add a small **worker** (or future Edge step) that `GET`s the signed URL and `PUT`s to **Cloudflare R2** or another S3-compatible bucket in the **same** region. Not required for MVP.

## 8. What we are *not* doing here

- **CloudKit / iCloud** as the primary lesson-video database: keep **Postgres** authoritative; use CloudKit later only for optional **device-local draft sync** if you need it.
- **Multi-region:** out of scope for this “single” deployment note.
