# WCS Operations Runbook: API Quota, Key Rotation, and External Dependency Incidents

## 1) Scope

This runbook covers:

- YouTube Data API key outages/quota exhaustion
- Crossref transient failures
- External checkout/social link misconfiguration

## 2) Detection Signals

- Telemetry event spikes:
  - `youtube.companion.failure`
  - `crossref.fetch.failure`
  - `course.load.failure`
- CI failure in `validate-external-links-config.sh`
- Manual QA reports of empty companion strips with valid enrollment

## 3) First Response (0-15 minutes)

1. Confirm environment variables in active build target:
   - `YOUTUBE_DATA_API_KEY`
   - `SOCIAL_*`
   - `STRIPE_MEMBERSHIP_CHECKOUT_URL`
   - `ADMIN_MERCHANT_DASHBOARD_URL`
2. Confirm network reachability from device/simulator.
3. Check if fallback behavior is functioning (stale cache/fallback panel).

## 4) YouTube Quota Exhaustion Procedure

1. Validate error pattern (`403`, quota messages).
2. Switch to fallback mode:
   - Keep lesson-native videos active.
   - Hide/de-emphasize companion strip when empty.
3. Rotate or switch API key:
   - Update secret in CI and local scheme.
   - Re-run smoke validation test.
4. Document incident timeline and estimated impact.

## 5) Key Rotation Procedure

1. Generate new restricted key in Google Cloud Console.
2. Restrict by API scope and app usage limits.
3. Update:
   - local Xcode scheme env
   - CI secrets/variables
4. Revoke old key after successful verification.
5. Run:
   - unit tests
   - simulator smoke (course detail companion strip)

## 6) Crossref Failure Procedure

1. Verify outage by direct endpoint check.
2. Confirm stale cache render path in app.
3. If sustained outage:
   - display existing cached metadata only
   - suppress repeated retries at UI level
4. Log incident and monitor recovery.

## 7) External Link Failure Procedure

1. Run CI script locally:
   - `bash scripts/validate-external-links-config.sh`
2. Confirm host allowlist coverage.
3. Patch bad URLs via environment, not hardcoded app changes.
4. Re-run launch smoke checklist.

## 8) Post-Incident Review Template

- Incident ID:
- Start time:
- End time:
- Affected components:
- User impact:
- Root cause:
- Corrective action:
- Preventive action:
- Owner:

## 9) Quarterly Preventive Tasks

- Rotate API keys and verify restrictions.
- Review host allowlist against active partners.
- Rehearse quota exhaustion and fallback behavior.
- Validate privacy manifest and App Store policy assumptions remain current.
