# WCS iOS App Store Production Checklist

Use this checklist to move from local build to App Store submission.
Use `docs/AppStoreSubmissionResponsePack.md` for copy-ready App Store Connect text and compliance answers.

## 1) Product Identity

- App Name: `World Class Scholars`
- Bundle ID: `wcs.WCS-Platform` (must match App Store Connect)
- Version (`MARKETING_VERSION`): set release version (for example `1.0.0`)
- Build (`CURRENT_PROJECT_VERSION`): increment for each upload

## 2) Assets and Branding

- App icon: configured in `Assets.xcassets/AppIcon.appiconset`
- Launch image: configured via `Info.plist` using `LaunchBrand`
- Verify all App Store icon variants have no alpha channel
- Screenshots: capture all required device classes in English (and other target locales)

## 3) Signing and Distribution

- In Apple Developer:
  - Create App ID for `wcs.WCS-Platform`
  - Create iOS Distribution certificate
  - Create App Store provisioning profile
- In Xcode:
  - Select your production Team
  - Use Release configuration with valid signing

## 4) Compliance and Policies

- Privacy Policy URL (required in App Store Connect)
- Terms of Use URL (recommended)
- App Privacy questionnaire completed accurately
- Export compliance answered (encryption declaration)
- Content rights confirmed for media used in app

## 5) Metadata (App Store Connect)

- Subtitle
- Description
- Keywords
- Support URL
- Marketing URL (optional)
- Age rating questionnaire
- Category selection (Primary + Secondary optional)

## 6) Build and Upload

- Archive in Xcode (`Any iOS Device`)
- Validate archive
- Upload to App Store Connect
- Confirm build appears under TestFlight / App version
- If upload fails on icon alpha or iCloud entitlement validation, apply fixes captured in `docs/AppStoreSubmissionResponsePack.md`
- Optional CLI archive/export script:
  - `chmod +x scripts/archive-appstore.sh`
  - `scripts/archive-appstore.sh`

## 7) TestFlight

- Internal testing enabled
- External testing (optional) with beta review
- Test notes included for reviewers/testers

## 8) Submission Readiness

- Final regression pass on production build
- No placeholder/demo credentials in production
- Push notification behavior verified if enabled
- Review notes added (demo account, workflows, special steps)

## 9) Submit for Review

- Attach build to version
- Complete all required fields
- Submit for review

---

## Notes for this repository

- Current app icon and launch branding were generated and wired in assets.
- Release-candidate versioning is set to `1.0.0` build `2`.
- Before final submission, replace placeholders with final brand-approved artwork if needed.
- Production submission responses are maintained in `docs/AppStoreSubmissionResponsePack.md`.
