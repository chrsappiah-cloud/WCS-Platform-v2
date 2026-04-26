# WCS iOS App Store Production Checklist

Use this checklist to move from a release candidate build to **App Store Connect** submission and **review approval**.

Copy-ready answers and reviewer text live in **`docs/AppStoreSubmissionResponsePack.md`**.  
Compliance narrative and outbound-link policy live in **`docs/AppStore_Review_Compliance_Packet.md`**.

## 1) Product identity

- **App name (store):** WCS Platform (align with App Store Connect record)
- **Bundle ID:** `org.worldclassscholars.platform` (must match App Store Connect and `WCS-Platform/project.yml`)
- **Marketing version:** `MARKETING_VERSION` in `WCS-Platform/project.yml` (e.g. `1.1.0`)
- **Build number:** `CURRENT_PROJECT_VERSION` in `WCS-Platform/project.yml` — increment for **every** upload
- **Team:** `DEVELOPMENT_TEAM` in `project.yml` (or set in Xcode); must match signing in Organizer

## 2) Assets and branding

- **App icon:** `WCS-Platform/Assets.xcassets/AppIcon.appiconset/` — ensure **1024×1024** variants are **opaque** if App Store rejects transparency
- **Launch:** `Info.plist` → `UILaunchScreen` / `LaunchBrand` in `Assets.xcassets/LaunchBrand.imageset/`
- **Screenshots:** capture required device sizes; starter shells under `production/apple/promotional/screenshot-placeholders/`
- **Privacy:** `WCS-Platform/PrivacyInfo.xcprivacy` present and accurate

## 3) Signing and distribution

- Apple Developer: App ID, Distribution certificate, App Store provisioning (or **Automatic** signing in Xcode)
- **Regenerate project before archive:** `cd WCS-Platform && xcodegen generate`
- **CLI archive + export:** `bash scripts/archive-appstore.sh` (writes archive under `build/`, IPA under `build/AppStoreExport/` when export succeeds)
- **Upload IPA:** `ASC_API_KEY_ID=… ASC_API_ISSUER_ID=… bash scripts/upload-appstore.sh` (expects `WCS-Platform.ipa` in export path; see script)

## 4) Compliance and policies

- Privacy Policy URL and Terms (as applicable) in App Store Connect
- **App Privacy** questionnaire matches `PrivacyInfo.xcprivacy` and runtime behavior
- **Export compliance** (encryption) answered; see `Info.plist` / entitlements as needed
- **External links / checkout:** allowlist validated — `bash scripts/validate-external-links-config.sh`
- Launch hardening: **`docs/Launch_Compliance_Hardening_Checklist.md`**

## 5) Metadata (App Store Connect)

- Subtitle, description, keywords, support URL, marketing URL (optional)
- Age rating, categories, **What’s New** for the attached build
- If subscriptions or external purchase flows exist, disclosure matches reviewer narrative (`AppStore_Review_Compliance_Packet.md`)

## 6) Build, validate, upload

- Xcode: **Product → Archive** (Release, **Any iOS Device** or generic iOS destination)
- Validate archive; upload via **Organizer** or **`upload-appstore.sh`**
- Confirm build processing in App Store Connect; attach build to the correct **version**
- If Apple returns metadata or entitlement issues, use **`docs/AppStoreSubmissionResponsePack.md`**

## 7) TestFlight

- Internal testing first; then external beta if needed (beta App Review)
- Test notes: sign-in, payments (if any), admin studio / demo account steps

## 8) Submit for review

- All required fields complete; build attached
- **Review notes:** demo credentials, video lesson path, outbound-link behavior
- Submit; monitor **Resolution Center** and respond with updated build if required

## 9) Post-release

- Monitor crashes and ratings; prepare next `CURRENT_PROJECT_VERSION` increment
- Tag release in git when store version goes live (optional team convention)

---

## Notes for this repository

- **XcodeGen** is the source of truth: `WCS-Platform/project.yml` → `WCS-Platform/WCS-Platform.xcodeproj` (relative to repo root; the generated project lives beside `project.yml` inside the `WCS-Platform/` app directory).
- **CI:** `.github/workflows/ios-ci-cd.yml` runs XcodeGen, simulator build, tests, and an **unsigned** Release archive artifact on `push`.
- **Production hub:** `production/apple/APPLE_STORE_PRODUCTION.md` links store art, version line, and workflow entrypoints.
