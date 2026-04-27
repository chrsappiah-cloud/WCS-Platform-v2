# WCS 90-Day Execution Plan

## Objective
Ship one capital-efficient wedge product and prove retention plus monetization with measurable data.

## Wedge Definition
- Vertical: Decision Science for early-career professionals.
- Primary journey: Discover -> Audit -> Progress -> Upgrade -> Certificate/Profile.
- Success target: reliable learner completion and first paid conversions in a controlled beta.

## Scope Guardrails
- One backend foundation only: Supabase.
- One app surface prioritized: iOS learner app + admin-lite workflow.
- One architecture pattern: modular monolith + BFF.
- No net-new expansion tracks until KPI gates are met.

## Month 1 (Weeks 1-4): Lock Decisions and Foundations
- Finalize wedge persona, outcome promise, and value proposition.
- Freeze MVP in/out scope and publish a single backlog source of truth.
- Finalize domain model and API contracts for:
  - catalog
  - learning progress
  - assessments
  - profile
  - upgrade entitlements
  - certificate records
- Implement Supabase foundations:
  - Auth
  - Postgres schema + RLS
  - Storage buckets + policies
  - environment separation (dev/staging/prod)
- Set analytics taxonomy and event instrumentation contracts.
- Enforce release pipeline gates (build, tests, artifact, crash reporting hookup).

## Month 2 (Weeks 5-8): Build and Integrate MVP
- Learner app delivery:
  - Discover catalog
  - Audit entry
  - Lesson playback + reading
  - Progress tracking
  - Basic quiz submission
  - Profile view
- Upgrade path:
  - paywall surface
  - entitlement checks
  - post-upgrade unlock behavior
- Certificate path:
  - completion trigger
  - certificate issuance record
  - profile attachment
- Admin-lite:
  - create/edit/publish course
  - upload media
  - basic visibility controls

## Month 3 (Weeks 9-12): Controlled Beta and Optimization
- Launch closed beta cohort.
- Run weekly funnel review:
  - discover -> audit conversion
  - lesson completion drop-off
  - upgrade conversion
  - certificate/profile engagement
- Prioritize fixes only for measurable bottlenecks.
- Cut non-performing features from near-term backlog.
- Produce investor-ready evidence pack:
  - product maturity summary
  - retention and conversion metrics
  - infrastructure and cost profile

## KPI Gates
- Audit start rate: >= 30%
- Lesson completion rate: >= 50%
- D7 retention: >= 20%
- Upgrade conversion from active learners: >= 5%
- Certificate view/share after completion: >= 40%

## Operating Rhythm
- Weekly: KPI review, cost review, backlog prune.
- Bi-weekly: architecture and reliability review.
- Monthly: roadmap checkpoint with explicit keep/cut decisions.

