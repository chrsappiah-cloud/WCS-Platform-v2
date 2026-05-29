# Notes for Review (Version 1.0 build 10)

Paste into **App Store Connect → App Review Information → Notes**.

WCS Platform is an education app: course discovery, enrollment, lesson playback, quizzes, assignments, and discussion.

**Reviewer path (Guideline 3.1.1):**
1. Launch app
2. **Profile** → **Membership & subscriptions**
3. **Subscribe with Apple** → purchase **Individual Pro** (`wcs.individual.pro.monthly`) or **Restore purchases**
4. **Programs** → open a subscription-gated course → confirm full access when Premium is active

**Payments:**
- Individual Premium digital content: **Apple In-App Purchase only** (StoreKit 2).
- No consumer Stripe/web checkout in Release builds.
- Enterprise/investor procurement links are B2B-only and labeled as not replacing Individual Pro IAP.

**Other:**
- Admin AI Course Studio is optional for review (admin-only).
- No special hardware required.
- iPad Air 11-inch (M3) launch path validated in build 1.0 (10).

**Attachment:** Upload PDF `WCS_App_Store_Review_Reply_v1_0_10.pdf` from Desktop if Connect allows attachments for this submission.
