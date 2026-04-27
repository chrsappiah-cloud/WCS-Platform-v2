# WCS Release Gates (CI/CD + TestFlight)

## Goal
Maintain fast delivery without shipping regressions by enforcing automated gates from commit to beta distribution.

## Branching and Promotion
- `main`: protected branch, always releasable.
- Feature branches: PR required, all required checks must pass.
- Tag-based release for signed distribution and archival.

## Required CI Gates (per PR and push to main)
1. Project generation integrity
   - `xcodegen generate` success
2. Configuration validation
   - external link and policy validation scripts pass
3. Build gate
   - iOS simulator build succeeds
4. Test gate
   - unit tests pass
   - stable UI smoke tests pass
5. Artifact gate (push to main)
   - unsigned/signed archive artifact created and uploaded
6. Manifest and compliance checks
   - privacy manifest present

## Test Strategy by Tier
- Tier 1 (blocking):
  - unit tests
  - deterministic UI smoke tests
- Tier 2 (non-blocking until hardened):
  - long-running exploratory E2E scenarios
  - flaky tests run in nightly workflow with triage alerts

## Observability Gates
- Crash reporting enabled in beta builds.
- Fatal crash regression threshold monitored before wider rollout.
- API error rate dashboard reviewed before release promotion.

## Deployment Stages
1. CI green on `main`
2. Internal TestFlight build
3. Controlled beta cohort
4. Metrics review checkpoint (retention/conversion/quality)
5. Wider release decision

## Rollback and Incident Response
- Keep last known good artifact available.
- Revert-to-green policy on severe regressions.
- Incident note required for any failed release candidate.

