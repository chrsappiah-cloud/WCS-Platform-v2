Hello App Review,

Thank you for the continued review of submission `bfa381c2-5902-4590-a217-e8d85a1fed22`, version 1.0 (9), reviewed on June 19, 2026.

We have updated the app to resolve Guideline 3.1.1. The iOS build does not present subscriptions, external subscription purchases, payment links, pricing, checkout, restore controls, product identifiers, or calls to action to buy paid digital content. Learner access is assigned by an organization administrator through account configuration outside the app, and the iOS experience is limited to signing in, viewing assigned programs, learning content, discussion, and profile/account context.

Changes made for this resubmission:

- Replaced stale commerce-oriented Profile copy with neutral organization-assigned access language.
- Removed stale commerce/test naming from the app target and UI test target.
- Removed mock assigned launch flags and replaced restricted-content copy with neutral organization-assigned access language.
- Removed external commerce configuration references from App Review materials and validation scripts.
- Updated App Review notes to make clear there is no subscription, commerce, external commerce, or paid digital-content purchase flow inside the app.

Reviewer path:

1. Launch the app and sign in with the provided reviewer account.
2. Open Profile -> Access.
3. Confirm the screen only states that learning access is assigned by the organization.
4. Open Programs and lessons. Unassigned content uses neutral organization-assigned access messaging only.
5. Confirm there are no buttons, links, restore controls, pricing displays, checkout paths, payment prompts, or calls to action to buy digital content.

Please continue review with this clarified build. We respectfully confirm that subscriptions cannot be purchased in the app by any payment mechanism, and no non-IAP external subscription purchase path is exposed in this iOS build.
