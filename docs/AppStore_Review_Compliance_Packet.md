# WCS iOS App Store Review Compliance Packet

Prepared for: WCS-Platform iOS release review  
Scope: Course delivery, admin generation surfaces, companion media, memberships, outbound links

## 1) Product Classification and Commerce Boundary

- App type: learning platform with courses, modules, lessons, quizzes, and assignments.
- In-app media: first-party lesson playback URLs (course-native).
- Companion media: YouTube discovery embeds based on lesson scripts and draft notes.
- Commerce:
  - External hosted checkout links are user-initiated and clearly labeled.
  - No raw card data is collected in app.
  - Apple IAP policy link is provided for entitlement model alignment.

## 2) Apple Review Narrative (Reviewer Notes Draft)

WCS-Platform provides structured learning programs with module-level video lessons, quizzes, and assignments.  
For enrolled users, the app may show companion educational clips sourced from YouTube Data API using lesson metadata.  
All external payments are opened only via explicit user taps and labeled as hosted checkout flows.

No hidden payment prompts, no background purchase behavior, and no non-user-initiated redirects are implemented.

## 3) External Link Controls

- Outbound URL validation uses centralized allowlist policy in app config.
- Accepted schemes: `https` and `http`.
- Allowed hosts include social platforms, Stripe domains, and Apple developer docs.
- CI gate validates all configured `SOCIAL_*`, `STRIPE_*`, and related env URLs.

## 4) Privacy and Data Minimization

- Privacy manifest file included: `WCS-Platform/PrivacyInfo.xcprivacy`.
- External enrichment requests (Crossref/YouTube) are query-based and avoid direct PII transmission.
- Telemetry uses structured event names and does not log card data or sensitive tokens.
- UserDefaults accessed for app config/state persistence under declared reason code.

## 5) Reliability and Fallback Behavior

- External API resilience:
  - retries
  - circuit breaker
  - stale-cache fallback
- Graceful degradation:
  - no YouTube API key -> explanatory fallback panel
  - upstream failures -> cached/stale-safe content path where available

## 6) Payment and Entitlement Review Checklist

- [ ] Confirm each paid entitlement is classified as Apple IAP-required or external-eligible.
- [ ] Confirm app copy does not imply unsupported in-app card capture.
- [ ] Confirm hosted checkout endpoints are production-ready and policy-compliant.
- [ ] Confirm settlement/payout flow is handled by PSP dashboard, not app storage.

## 7) Release Evidence Bundle

- Build/test artifacts from CI workflow
- Link validation script run output
- Screenshots of:
  - enrollment and lesson playback
  - companion video strip with key present and absent
  - membership hub and outbound checkout labels
  - privacy-related settings disclosures (if applicable)

## 8) Launch Gate Decision

Release candidate can proceed to beta review when all section 6 checks are complete and CI gates pass.
