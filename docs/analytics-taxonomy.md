# WCS Analytics Taxonomy (MVP)

## Principles
- Track behavior needed to prove retention and monetization.
- Keep event naming stable and versioned.
- Include enough context for segmentation without collecting unnecessary PII.

## Required Event Envelope
Every event should include:
- `event_name`
- `event_ts`
- `user_id` (or anonymous/session id before auth)
- `course_id` (when relevant)
- `module_id` (when relevant)
- `lesson_id` (when relevant)
- `plan_tier` (`audit`, `free`, `paid`)
- `platform` (`ios`)
- `app_version`
- `build_number`

## Core Funnel Events
- `discover_viewed`
- `catalog_item_opened`
- `audit_started`
- `lesson_started`
- `lesson_completed`
- `quiz_started`
- `quiz_submitted`
- `course_completed`
- `upgrade_viewed`
- `upgrade_started`
- `upgrade_completed`
- `certificate_viewed`
- `profile_viewed`
- `profile_shared`

## Reliability and UX Events
- `video_playback_started`
- `video_playback_failed`
- `api_request_failed`
- `screen_render_slow`

## Derived KPI Definitions
- Audit Start Rate:
  - users with `audit_started` / users with `discover_viewed`
- Lesson Completion Rate:
  - lessons with `lesson_completed` / lessons with `lesson_started`
- D7 Retention:
  - users active on day 7 / new users cohort
- Upgrade Conversion:
  - users with `upgrade_completed` / users with `upgrade_viewed`
- Completion-to-Certificate Engagement:
  - users with `certificate_viewed` / users with `course_completed`

## Instrumentation Ownership
- iOS app: emits UI and learner behavior events.
- BFF/backend: emits entitlement, completion, and critical API outcomes.
- Data checks:
  - daily event volume sanity
  - null field monitoring for required dimensions
  - funnel break detection alerts

## Implementation Milestones
- Week 1: event schema + naming lock.
- Week 2: client instrumentation for top funnel.
- Week 3: backend enrichment + dashboard setup.
- Week 4+: weekly taxonomy audit and drift control.

