# ARC Shield Submission Checklist

Use this checklist before each App Store submission.

## Build Integrity

- [ ] Clean build succeeds on current Xcode and SDK.
- [ ] Unit tests pass (`WCS-PlatformTests`).
- [ ] UI smoke and review-flow tests pass (`WCS-PlatformUITests`).

## Reviewer-Critical Flows

- [ ] App launches successfully in normal mode.
- [ ] App launches in offline mode (`-mockNetwork offline`).
- [ ] Discover, Programs, Discussion, and Profile tabs are reachable.
- [ ] Login/session edge behavior is stable with `-seedExpiredToken`.
- [ ] Permission-denied journey remains navigable (`-mockPermissions deniedCamera`).
- [ ] Subscription loading failure mode does not crash (`-mockStoreKit productsFailure`).

## Stability and Regression

- [ ] No blank screens or permanent loading indicators.
- [ ] Last 10 rejection regressions are green.
- [ ] Manual exploratory run completed on physical device (>=10 minutes).

## Release Evidence

- [ ] Regression ledger updated with this release build number.
- [ ] Known issues triaged and severity-assessed.
- [ ] App Review notes updated for any non-obvious behavior.
