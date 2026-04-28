# WCS iOS Launch Compliance Hardening Checklist

Use this checklist before each beta/prod release candidate.

## P0 (Must pass)

- [ ] Payment routing decision documented per entitlement:
  - `informational`
  - `external_checkout`
  - `app_native_iap`
- [ ] No raw PAN/CVV handling in app code or logs.
- [ ] Outbound URLs validated by host allowlist and HTTPS policy (`scripts/validate-external-links-config.sh`).
- [ ] `PrivacyInfo.xcprivacy` present and reviewed for accessed API reason codes.
- [ ] External API fallback verified:
  - YouTube key missing
  - YouTube quota/5xx
  - Crossref unavailable
- [ ] App Review wording confirms user-initiated external navigation and business model clarity.

## P1 (Should pass)

- [ ] Crossref and YouTube adapter decoding tests cover malformed payloads and empty data.
- [ ] Cache fallback works with stale entries and online outage.
- [ ] Telemetry sampled for:
  - `course.load.*`
  - `crossref.fetch.*`
  - `youtube.companion.*`
- [ ] Admin draft companion strip tested with and without API key.

## P2 (Nice to have before broad launch)

- [ ] Relevance filtering and unsafe-term filtering thresholds tuned with beta feedback.
- [ ] Support runbook exercised for key rotation and quota exhaustion.
- [ ] Device matrix pass on at least two physical iPhone models.

## Manual QA playbooks
- [Module lesson video backups and YouTube companion streaming](./MANUAL_TESTING_MODULE_VIDEO_AND_YOUTUBE.md) — step-through for admin HTTPS fallbacks and enrolled YouTube backup UI (pairs with P0/P1 YouTube items above).
