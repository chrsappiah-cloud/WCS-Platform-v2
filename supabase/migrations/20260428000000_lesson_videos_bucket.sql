-- Private bucket for AI-generated lesson MP4s (Edge Function uploads with service role).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lesson-videos',
  'lesson-videos',
  false,
  524288000,
  array['video/mp4', 'video/quicktime']::text[]
)
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
