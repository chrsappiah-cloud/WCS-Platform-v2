# WCS Platform — Apple App Store Production

This folder supports **App Store Connect** submission for the native iOS app built from **XcodeGen** (`WCS-Platform/project.yml`).

## Current release (upgrade)

- **Marketing version:** `1.1.0` (`MARKETING_VERSION` in `WCS-Platform/project.yml`)
- **Build:** `2` (`CURRENT_PROJECT_VERSION`)
- **Bundle ID:** `org.worldclassscholars.platform`
- **Team ID:** `TM2WG7HH96` (override locally if your membership differs)

## 1) Source-of-truth locations

| Item | Path |
|------|------|
| Xcode project (generated) | `WCS-Platform/WCS-Platform.xcodeproj` |
| XcodeGen spec | `WCS-Platform/project.yml` |
| App icons (asset catalog) | `WCS-Platform/Assets.xcassets/AppIcon.appiconset/` |
| Launch brand image | `WCS-Platform/Assets.xcassets/LaunchBrand.imageset/` |
| Privacy manifest | `WCS-Platform/PrivacyInfo.xcprivacy` |
| Entitlements | `WCS-Platform/WCS_Platform.entitlements` |
| App `Info.plist` | `WCS-Platform/Info.plist` |
| **Promotional / store art (this pack)** | `production/apple/promotional/` |

## 2) Regenerate Xcode project (required before archive)

```bash
cd WCS-Platform && xcodegen generate
```

## 3) Simulator build (sanity)

```bash
xcodebuild \
  -project "WCS-Platform/WCS-Platform.xcodeproj" \
  -scheme "WCS-Platform" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  build
```

## 4) Archive for App Store Connect (device, signed)

In **Xcode**: **Product → Archive** with scheme **WCS-Platform**, **Release**.

CLI (unsigned artifact for CI; for store uploads use Xcode Organizer + signing):

```bash
bash scripts/ios-archive.sh
```

CI reference: `.github/workflows/ios-ci-cd.yml` (XcodeGen + build + test + unsigned archive artifact on `push`).

## 5) App Store Connect — listing copy (starter)

**Name:** WCS Platform  
**Subtitle:** Learn with clarity and structure  
**Promotional text:** Structured programs, progress you can trust, and companion media—built for serious learners and teams.  
**Keywords:** learning,courses,education,professional development,modules,progress,subscription,WCS  

**What’s New (1.1.0)**  
- Pipeline and stability improvements for discovery, media, and offline-tolerant networking.  
- Privacy and compliance hardening aligned with App Store requirements.  
- Test and CI coverage expanded for release confidence.

## 6) Pre-submission checklist

- [ ] Run `bash scripts/validate-external-links-config.sh`
- [ ] Review `docs/Launch_Compliance_Hardening_Checklist.md`
- [ ] Confirm **1024** app icons are **opaque** (no alpha) if App Store flags transparency
- [ ] Age rating, export compliance, and subscription / external purchase disclosures completed in App Store Connect
- [ ] Physical device smoke test (tabs, video lesson, admin studio if applicable)

## 7) Screenshot / marketing assets

PNG templates live under `production/apple/promotional/`:

- `AppStore-Hero-2732x2048.png` — iPad / hero canvas
- `Social-1200x630.png` — link preview / Open Graph
- `Story-1080x1920.png` — vertical story
- `Poster-2048x2732.png` — tall poster
- `screenshot-placeholders/iPhone-1290x2796-1.png` … `-4.png` — iPhone 6.5" screenshot shells (replace with real UI captures before submission)

Use them in App Store Connect **App Preview and Screenshots** and for social launch posts.
