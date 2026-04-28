-- Single-region canonical audit trail for lesson video renders (Edge Function → Postgres).
-- Access: service_role only (no anon/authenticated direct reads/writes via PostgREST).

create extension if not exists "pgcrypto";

create table if not exists public.wcs_lesson_video_render_jobs (
  id uuid primary key default gen_random_uuid(),
  course_id text not null,
  module_id text not null,
  lesson_id text not null,
  pipeline_mode text,
  provider text not null,
  status text not null check (status in ('queued', 'in_progress', 'completed', 'failed')),
  generation_prompt_excerpt text,
  storyboard_json jsonb,
  request_json jsonb not null,
  playback_url text,
  error_message text,
  client_app_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.wcs_lesson_video_render_jobs is
  'WCS lesson video pipeline: one row per Edge invocation outcome (single-region Supabase Postgres).';

create index if not exists wcs_lesson_video_render_jobs_course_lesson_created_idx
  on public.wcs_lesson_video_render_jobs (course_id, lesson_id, created_at desc);

create index if not exists wcs_lesson_video_render_jobs_status_created_idx
  on public.wcs_lesson_video_render_jobs (status, created_at desc);

-- Harden: Edge uses service_role; learners must not scrape job history via anon key.
revoke all on public.wcs_lesson_video_render_jobs from anon, authenticated;
grant select, insert, update, delete on public.wcs_lesson_video_render_jobs to service_role;
grant all on public.wcs_lesson_video_render_jobs to postgres;
