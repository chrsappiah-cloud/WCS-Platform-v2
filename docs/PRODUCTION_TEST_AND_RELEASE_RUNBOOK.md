# Production testing and Apple release runbook

This repository is **iOS only** (SwiftUI + XcodeGen). Scope is the native WCS app and its CI/docs; there is no secondary web or Node workspace tracked here.

Canonical iOS remote: [https://github.com/chrsappiah-cloud/WCS-Platform.git](https://github.com/chrsappiah-cloud/WCS-Platform.git)

---

## Copy-paste (from repository root)

The clone root contains **`scripts/`** and the app directory **`WCS-Platform/`** (which holds `project.yml` and `WCS-Platform.xcodeproj`). Run:

```bash
# 1) Regenerate Xcode project (inside app directory)
cd WCS-Platform && xcodegen generate && cd ..

# 2) Validate outbound URL allowlist
bash scripts/validate-external-links-config.sh

# 3) Unit tests only (replace simulator name if needed; list: xcrun simctl list devices available)
cd WCS-Platform && xcodebuild test \
  -project WCS-Platform.xcodeproj \
  -scheme WCS-Platform \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -sdk iphonesimulator \
  -parallel-testing-enabled NO \
  -only-testing:WCS-PlatformTests \
  -skip-testing:WCS-PlatformUITests \
  && cd ..

# 4a) UI tests only — from repo root (chmod +x scripts/run-ui-tests-only.sh once if needed)
bash scripts/run-ui-tests-only.sh 'platform=iOS Simulator,name=iPhone 17'

# 4b) OR full unit + UI after erasing all simulators (destructive)
bash scripts/run-stable-tests.sh
```

**In Xcode:** open `WCS-Platform/WCS-Platform.xcodeproj`, pick a simulator, **Product → Test (⌘U)** for the default scheme test action.

---

## 1) Unit tests (`WCS-PlatformTests`)

**In Xcode:** Scheme **WCS-Platform** → **Product → Test (⌘U)** (fastest feedback).

**CLI (unit tests only, skip UI):**

```bash
cd /path/to/WCS-Platform/WCS-Platform && xcodegen generate
xcodebuild test \
  -project WCS-Platform.xcodeproj \
  -scheme WCS-Platform \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WCS-PlatformTests \
  -skip-testing:WCS-PlatformUITests
```

**Focused “UI-adjacent” unit checks** (SwiftUI contracts, captions, trust cluster, playback policy):

```bash
./scripts/run-investor-ui-tests.sh 'platform=iOS Simulator,name=iPhone 17'
```

**GitHub Actions:** on every PR and push to `main`, **CI Build and Test** runs unit tests and skips `WCS-PlatformUITests` for stability (see `.github/workflows/ios-ci-cd.yml`).

---

## 2) UI tests (`WCS-PlatformUITests`)

UITests live in `WCS-PlatformUITests/` and drive the full app (tab bar, catalog navigation, video playback smoke, etc.). One long-path test is **skipped** in code (`testManualBackupDraftCreatePublishAndPlaybackFlow`) because it is flaky on simulator.

**CLI (UI tests only):**

```bash
./scripts/run-ui-tests-only.sh 'platform=iOS Simulator,name=iPhone 17'
```

**Full suite (unit + UI), clean sim** — destructive (erases all simulators):

```bash
./scripts/run-stable-tests.sh
```

**GitHub Actions:** optional **Run UI tests** workflow — `.github/workflows/ios-ui-tests.yml` — trigger manually (**Actions → iOS UI Tests → Run workflow**) before a major release or TestFlight cut.

---

## 3) Prepare for Apple production (App Store)

Follow these in order; they are the authoritative checklists:

| Step | Document |
|------|----------|
| Store metadata, signing, archive, upload | [`docs/AppStoreProductionChecklist.md`](./AppStoreProductionChecklist.md) |
| Hub (paths, version line, scripts) | [`production/apple/APPLE_STORE_PRODUCTION.md`](../production/apple/APPLE_STORE_PRODUCTION.md) |
| Reviewer narrative, commerce, links | [`docs/AppStore_Review_Compliance_Packet.md`](./AppStore_Review_Compliance_Packet.md) |
| Copy-ready responses | [`docs/AppStoreSubmissionResponsePack.md`](./AppStoreSubmissionResponsePack.md) |
| P0/P1 launch hardening | [`docs/Launch_Compliance_Hardening_Checklist.md`](./Launch_Compliance_Hardening_Checklist.md) |
| Manual feature QA (video backup + YouTube) | [`docs/MANUAL_TESTING_MODULE_VIDEO_AND_YOUTUBE.md`](./MANUAL_TESTING_MODULE_VIDEO_AND_YOUTUBE.md) |

**Bundle ID alignment (critical):** `WCS-Platform/project.yml` currently sets `PRODUCT_BUNDLE_IDENTIFIER` to `wcs.WCS-Platform`. Production docs reference `org.worldclassscholars.platform` for App Store Connect. **Before submission**, make `project.yml`, Xcode signing, and **App Store Connect** use the **same** bundle identifier.

**Commands often used before upload:**

```bash
cd WCS-Platform && xcodegen generate
bash scripts/validate-external-links-config.sh
bash scripts/archive-appstore.sh
# then upload-appstore.sh with ASC API key env vars — see App Store checklist
```

---

## 4) CI/CD enforcement

Branch protection: require **CI Build and Test** to pass on `main` (see [`docs/release-gates.md`](./release-gates.md)).
