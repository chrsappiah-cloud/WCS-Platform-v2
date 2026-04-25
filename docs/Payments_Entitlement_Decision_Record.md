# WCS Payments and Entitlement Decision Record

Purpose: document policy and implementation decisions for revenue flows in WCS iOS.

## Decision Framework

Each monetized route must be categorized as exactly one:

1. `app_native_iap`
   - Digital entitlement sold inside iOS app and consumed in app.
   - Must use StoreKit and Apple commerce rules.

2. `external_checkout`
   - User-initiated navigation to hosted PSP checkout.
   - App does not capture card details directly.
   - Eligibility must be validated against App Store policy.

3. `informational_only`
   - No purchase action in app; informational links only.

## Current WCS Mapping (Initial)

- Membership hub deep link (`STRIPE_MEMBERSHIP_CHECKOUT_URL`): `external_checkout` (pending legal/product sign-off).
- Merchant/Connect dashboard link (`ADMIN_MERCHANT_DASHBOARD_URL`): `external_admin_finance_tool`.
- Course enrollment CTA:
  - If no native StoreKit integration exists, treat as non-transactional until policy sign-off.

## Required Approvals Before Production

- [ ] Product owner sign-off on entitlement taxonomy.
- [ ] Legal/compliance sign-off on App Store policy interpretation.
- [ ] Finance sign-off on settlement routing and reconciliation.
- [ ] Security sign-off that no PAN/CVV is persisted or logged.

## Technical Guardrails Implemented

- Centralized host allowlist for outbound URLs.
- HTTPS/HTTP scheme checks before rendering links.
- CI validation script for configured external endpoints.
- Explicit in-app text clarifying hosted checkout and PSP handling.

## Operational Controls

- Key contacts:
  - Product: ____________________
  - Compliance: ____________________
  - Finance: ____________________
  - Security: ____________________
- Incident response SLA for payment-route outages: ________
- Monthly policy review cadence: ________

## Final Decision Log

| Date | Flow | Decision | Approver | Notes |
|---|---|---|---|---|
| TBD | Membership checkout | Pending | TBD | Awaiting App Store policy sign-off |
| TBD | Admin payout dashboard | Approved | TBD | External admin-only utility |
