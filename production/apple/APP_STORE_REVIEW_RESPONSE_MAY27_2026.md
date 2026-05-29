# App Store Review Response (Submission ID bfa381c2-5902-4590-a217-e8d85a1fed22)

Use this response in App Store Connect Resolution Center for the rejection dated May 27, 2026.

---

Hello App Review Team,

Thank you for the detailed feedback.

We investigated both items and prepared an updated build for resubmission.

## Guideline 2.1(a) – Performance (crash shortly after launch)

We reproduced and addressed launch-path stability on iPad-class devices (including iPadOS 26.5).  
The update includes:

- startup/bootstrap hardening in app launch flow
- additional launch guards for device/runtime configuration handling
- expanded regression coverage for iPhone and iPad launch paths
- production checklist updates for symbolication + crash-pattern triage before submission

Validation completed on:
- iPhone 17 Pro Max (physical)
- iPhone 17 Pro Max simulator
- iPad-class simulator coverage in release test pass

## Guideline 2.1(b) – Business model information

1. **Who are paid users?**  
   Adult learners, professionals, and organization-sponsored learners who use premium educational content.

2. **Where can users purchase content/subscriptions?**  
   - Individual digital subscriptions: **Apple In-App Purchase** in app.  
   - Organization/enterprise access: outside-app B2B contracts managed by organizations.

3. **What previously purchased items can be accessed?**  
   - Active individual subscriptions restore premium course/module access for the authenticated account.  
   - Organization-sponsored entitlements provide access to assigned content for organization members.

4. **What paid features unlock without IAP?**  
   - Only organization/enterprise B2B entitlement access.  
   - No separate consumer digital unlock bypasses IAP for individual users.

If needed, we can provide a dedicated reviewer account and a concise validation path for subscription and entitlement behavior.

## Guideline 3.1.1 – In-App Purchase (May 29, 2026)

We addressed the rejection that Premium digital content was available outside In-App Purchase:

- **Individual Pro** is sold only with **Apple In-App Purchase** (`SubscriptionStoreView` + StoreKit 2) under Profile → Membership & subscriptions → Subscribe with Apple.
- **Restore purchases** is available in the same screen (StoreKit restore + entitlement sync).
- **Removed** consumer-facing hosted Stripe membership checkout from Release builds (debug-only in developer builds).
- Premium entitlement unlocks course access via `Transaction.currentEntitlements` and is reflected in the Profile **Premium** status.
- Enterprise and investor procurement remain external B2B flows and are labeled as not replacing Individual Pro IAP.

**Reviewer path:** Profile tab → Membership & subscriptions → Subscribe with Apple → purchase or restore → return to a subscription-gated program to confirm access.

Thank you.

