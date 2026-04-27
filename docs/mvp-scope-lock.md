# WCS MVP Scope Lock (90 Days)

## Scope Lock Rule
Any feature not directly improving acquisition, completion, conversion, or reporting is out of MVP.

## In Scope (P0)
- Catalog discovery (single flagship vertical).
- Audit mode access path.
- Course consumption:
  - video lessons
  - reading lessons
  - progress tracking
- Basic assessments:
  - quiz submission
  - completion state
- Upgrade flow:
  - paywall/upgrade CTA
  - entitlement unlock
- Certificate/Profile:
  - completion certificate record
  - profile visibility for completion status
- Discussion-lite:
  - basic threaded discussion read/write
- Admin-lite:
  - create/edit/publish course
  - upload and link media

## Explicitly Out of Scope (P2+)
- Multi-vertical catalog expansion.
- Multi-tenant enterprise org administration.
- Advanced social features (mentions, moderation suite, reputation systems).
- Complex real-time collaboration.
- AI-first dynamic curriculum generation in learner path.
- Multi-provider backend abstraction (Firebase + Supabase dual path).
- Custom infra for messaging, transcoding, or analytics pipelines.

## Technical Constraints
- Backend foundation: Supabase only.
- Architecture: modular monolith + BFF.
- Client priority: iOS first.
- Shared components favored over one-off UI implementations.

## Change Control
- Scope changes require:
  1) KPI justification
  2) effort estimate
  3) displacement decision (what gets cut)
- No additive scope without a corresponding removal during MVP window.

## Exit Criteria for MVP
- End-to-end learner flow functional:
  Discover -> Audit -> Progress -> Upgrade -> Certificate/Profile
- CI/CD green on main branch.
- Production crash and analytics instrumentation active.
- First cohort metrics available for retention and conversion.

