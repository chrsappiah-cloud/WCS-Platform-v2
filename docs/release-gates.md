# WCS Release Gates (CI/CD + TestFlight)

## Goal
Maintain fast delivery without shipping regressions by enforcing automated gates from commit to beta distribution.

## Branching and Promotion
- `main`: protected branch, always releasable.
- Feature branches: PR required, all required checks must pass.
- Tag-based release for signed distribution and archival.

## GitHub enforcement (recommended)
On the repository **Settings → Rules → Rulesets** (or classic branch protection for `main`):
- Require a pull request before merging.
- Require status check **“CI Build and Test”** (workflow `iOS CI/CD`) to pass.
- Require branches to be up to date before merging (optional but reduces drift).
- Block force-push to `main` where policy allows.

The workflow lives at `.github/workflows/ios-ci-cd.yml` and runs on every PR and push to `main`.

## Required CI Gates (per PR and push to main)
1. Project generation integrity
   - `xcodegen generate` success
2. Configuration validation
   - external link and policy validation scripts pass
3. Build gate
   - iOS simulator build succeeds
4. Test gate
   - unit tests pass (`WCS-PlatformTests`; GitHub Actions skips `WCS-PlatformUITests` on PR/push until UI harness is stabilized locally)
   - optional UI smoke tests (run in Xcode or a dedicated workflow when ready)
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

## Manual QA playbooks (reference)
Optional human-run checklists for features that sit alongside automated gates (Tier 2 / exploratory):
- [Module lesson video backups and YouTube companion streaming](./MANUAL_TESTING_MODULE_VIDEO_AND_YOUTUBE.md)
