# OpenAI Video/Audio API Integration Guide (WCS)

This guide maps WCS course module scripts to OpenAI-native video/audio APIs.

## Implemented in App (Current)

- Module/unit lesson notes are converted into script segments for each generated tutorial.
- Each generated lesson now includes:
  - YouTube companion search URL customized to course/module/unit context
  - Narration text payload for TTS generation
  - Audio and microphone readiness checklist
  - OpenAI endpoint recommendations embedded in metadata

## Recommended OpenAI Pipeline

### 1) Video generation (Sora)

- Create video job: `POST /v1/videos`
  - Model: `sora-2` or `sora-2-pro`
  - Inputs: `prompt`, `seconds`, `size`
- Poll job status: `GET /v1/videos/{video_id}`
- Download MP4: `GET /v1/videos/{video_id}/content`

### 2) Narration audio generation (TTS)

- Generate narration audio: `POST /v1/audio/speech`
  - Model: `gpt-4o-mini-tts`
  - Inputs: `input`, `voice`, optional `instructions`
  - Output format: `aac` or `mp3` for iOS playback

### 3) Microphone QA and transcript validation

- Validate presenter/microphone capture: `POST /v1/audio/transcriptions`
  - Model: `gpt-4o-transcribe` (or `gpt-4o-mini-transcribe`)
  - Inputs: audio file upload and optional prompt context
  - Use transcripts to score clarity and coverage against module script targets

## YouTube Companion Policy

- Keep YouTube links as companion references (not replacements for course-native generated assets).
- For each module/unit, use course/module/lesson title + level as search terms.
- Curate and review selected videos before presenting to learners in production.

## iOS Audio/Microphone Requirements

- Ensure app has a microphone usage string in `Info.plist` when recording is enabled.
- Use `AVAudioSession` readiness checks before recording sessions.
- Gracefully fallback to playback-only mode when microphone is unavailable or denied.

## Operational Notes

- Cache generated media metadata by course and lesson IDs.
- Version prompts so regenerated videos are reproducible.
- Keep copyright-safe source references and moderation checks in prompt pipelines.
