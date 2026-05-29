# App Store Connect — Resolution Center Reply (copy/paste)

**Submission ID:** bfa381c2-5902-4590-a217-e8d85a1fed22  
**Resubmission build:** 1.0 (10)  
**Review device tested:** iPad Air 11-inch (M3) class + iPhone (physical UI E2E)

---

Hello App Review Team,

Thank you for your review on May 29, 2026. We have submitted an updated build **1.0 (10)** that resolves **Guideline 3.1.1 – In-App Purchase**.

## Guideline 3.1.1 – In-App Purchase

**Issue:** Premium digital content was accessible without In-App Purchase.

**Resolution in build 1.0 (10):**

1. **Individual Pro** (Premium course access) is now purchased exclusively with **Apple In-App Purchase** using StoreKit 2 (`SubscriptionStoreView`) in the app.
2. **Restore purchases** is available on the same screen (Profile → Membership & subscriptions → Subscribe with Apple).
3. Premium unlock is enforced through **StoreKit entitlements** (`Transaction.currentEntitlements`) and reflected in Profile as **Premium: Active** after purchase or restore.
4. **Consumer-facing hosted Stripe membership checkout has been removed from Release builds.** External links remain only for organization/investor B2B procurement, clearly labeled as not replacing Individual Pro IAP.
5. Developer/mock premium toggles are **Debug-only** and are not present in App Store Release builds.

## How to validate (reviewer path)

1. Open **Profile** tab.
2. Tap **Membership & subscriptions**.
3. Under **Subscribe with Apple**, subscribe to **Individual Pro** (product ID: `wcs.individual.pro.monthly`) or tap **Restore purchases** if already subscribed.
4. Return to **Programs** and open a subscription-gated course — full lesson access should be enabled when Premium is active.

## Guideline 2.1(a) – Launch stability (prior feedback)

We also retained launch hardening for iPad-class devices validated on iPad Air 11-inch (M3) and iPhone hardware.

## Business model (2.1(b))

- **Individual learners:** Apple In-App Purchase only for Premium digital content.
- **Organizations:** B2B seat/contract access managed outside the consumer app; does not bypass Individual Pro IAP.

Please let us know if you need a sandbox tester account or additional metadata.

Thank you.
