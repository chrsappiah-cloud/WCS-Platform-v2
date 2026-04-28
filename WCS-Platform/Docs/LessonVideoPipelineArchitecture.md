# Lesson video pipeline (iOS + BFF)

This document aligns the WCS lesson video feature with a **Mootion-style orchestration model**: text → narrative structure → scenes (visuals, pacing, transitions) → narration → composed output — not a single end-to-end “magic video” call.

## Principles

1. **Scene-first:** generate **many short clips** (roughly 5–20 seconds each), then **stitch** with TTS, captions, bumpers, and transitions in a compositor (FFmpeg, cloud render, or vendor compose step).
2. **Provider adapter:** OpenAI **Videos / Sora**, Luma, LTX, self-hosted SVD, etc. are **swappable backends** behind the same storyboard contract. **OpenAI’s current Sora 2 video / Videos API is explicitly time-boxed** in vendor messaging (verify latest docs for shutdown / migration dates); the BFF must not hard-code a single vendor.
3. **Six stages (reference architecture)**

| Stage | Role |
|--------|------|
| **Ingest** | Lesson text, module outline, objectives, glossary, assessment hooks. |
| **Plan** | LLM / parser → scenes: duration, shot type, narration, on-screen text, visual intent. |
| **Generate** | Per-scene media jobs (diffusion video, image-guided first frame, stock retrieval). |
| **Narrate** | TTS + timed captions per scene. |
| **Compose** | Timeline: transitions, lower-thirds, intro/outro, module markers, export MP4/HLS. |
| **Review** | Teacher edits, per-scene rerender, thumbnails/spritesheets, publish gate. |

## iOS contract (today)

- Types: `LessonVideoStoryboard`, `LessonVideoScenePlan`, `LessonVideoClientPipelineMode`, `LessonVideoPipelineStage` in `Learning/VideoPipeline/`.
- **POST** body: `RemoteLessonTextToVideoRequest` includes:
  - `textToVideoPrompt` — **legacy** master prompt (still required for older Edge functions).
  - `storyboard` — structured `scenes[]` when using `pipelineMode: "scene_orchestration_v1"`.
  - `pipelineMode` — `"legacy_single_clip"` or `"scene_orchestration_v1"`.
- **Response** (unchanged for MVP): `{ "playbackURL": "https://…", "message"?: "…" }` pointing at the **final** composed asset (or a signed URL to it).

Future responses may add `jobId`, per-scene statuses, or preview URLs; clients should tolerate extra JSON keys.

## Scene schema (`LessonVideoScenePlan`)

| Field | Purpose |
|--------|---------|
| `sceneId` | Stable id for rerender / status tracking. |
| `learningObjective` | Optional Bloom-style objective for the beat. |
| `narrationText` | TTS source for the scene. |
| `visualPrompt` | Video model prompt (shot, setting, lighting). |
| `shotType` | e.g. explain, demo, recap. |
| `durationSeconds` | Target length hint for the clip. |
| `onScreenText` | Lower-third / title safe text. |
| `referenceImageURL` | Optional first-frame / character consistency. |
| `needsDiagram` | Hint for diagram/stock B-roll branch. |
| `assessmentCheckpoint` | Optional inline check. |

## Database (single-region Supabase)

- **Table:** `public.wcs_lesson_video_render_jobs` (see migration `supabase/migrations/20260428140000_lesson_video_render_jobs.sql`).
- **Purpose:** audit trail for each Edge invocation — `pipeline_mode`, `storyboard_json`, full `request_json`, `generation_prompt_excerpt`, `playback_url` or `error_message`, `provider`, `status`.
- **Access:** `REVOKE` for `anon` / `authenticated`; **`service_role`** only (Edge Function with service key). Query in SQL editor or a future admin API.
- **Backups / DR:** rely on Supabase project backups; optional same-region **R2** (or S3) replication of finished MP4s — see `supabase/README.md` §7.

## BFF responsibilities (Supabase Edge / Node)

1. Accept `storyboard` + `pipelineMode`; if orchestration mode: enqueue **N** clip jobs, run TTS, **compose**, upload final MP4 to storage, return signed `playbackURL`.
2. Persist **job rows** (queued → in_progress → completed | failed) for teacher dashboards and retries.
3. Respect **guardrails** (copyright, likeness, PII) at generation time; educational products should prefer stylized / non-likeness visuals unless using an approved avatar pipeline.

## References (external)

- OpenAI video generation / Videos API (verify current status and deprecation notices).
- Mootion public product narrative (storyboard, pacing, narration, long-form editing).
- Internal: `VideoGeneration-InfoPlistKeys.txt`, `supabase/README.md`, Edge function `wcs-lesson-text-to-video`.
