# WCS MVP Backlog Priority Map (P0/P1/P2)

## P0 (Must Ship in 90 Days)
- Wedge catalog setup for one flagship vertical.
- Discover screen with course entry points.
- Audit path initiation and gating.
- Lesson delivery:
  - video playback
  - reading rendering
  - progress persistence
- Quiz submission and pass/fail state.
- Upgrade flow with entitlement unlock.
- Certificate generation record and profile attachment.
- Profile screen with completion visibility.
- Admin-lite:
  - create/edit/publish course
  - media upload and linking
- Supabase integration:
  - auth
  - core schema
  - storage
  - RLS policies
- Analytics event instrumentation for all funnel stages.
- CI/CD release gates and TestFlight internal distribution.

## P1 (Ship Only If P0 Stable and Metrics Instrumented)
- Discussion-lite UX polish.
- Improved search/filter on catalog.
- Learner notification nudges for incomplete lessons.
- Basic instructor/admin reporting dashboard.
- Certificate/profile sharing UX improvements.

## P2 (Defer Beyond MVP)
- Multi-vertical marketplace expansion.
- Full enterprise org administration.
- Advanced community moderation and social graph.
- Deep personalization/recommendation engine.
- Multi-region custom infra and service decomposition.
- Dual-backend support strategy.

## Backlog Hygiene Rules
- Weekly prune:
  - remove stale stories
  - merge duplicates
  - re-rank by KPI impact
- Every item must map to one metric:
  - acquisition
  - completion
  - conversion
  - reporting confidence
- No unowned stories; each card has a clear owner and acceptance criteria.

