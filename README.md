# WCS-Platform (iOS)

Native SwiftUI learning app for World Class Scholars.

## Repository

**Git (HTTPS):** [https://github.com/chrsappiah-cloud/WCS-Platform.git](https://github.com/chrsappiah-cloud/WCS-Platform.git)

```bash
git clone https://github.com/chrsappiah-cloud/WCS-Platform.git
cd WCS-Platform
```

**Git (SSH):** `git@github.com:chrsappiah-cloud/WCS-Platform.git`

## Open in Xcode

- Generate the Xcode project: `cd WCS-Platform && xcodegen generate`
- Open `WCS-Platform/WCS-Platform.xcodeproj`

## CI/CD

- **PR / push:** `.github/workflows/ios-ci-cd.yml` — XcodeGen, simulator build, **unit tests** (`WCS-PlatformTests`), unsigned Release archive on `main`.
- **UI tests (optional):** `.github/workflows/ios-ui-tests.yml` — run manually in GitHub Actions or on a weekly schedule.

Release gates and branch-protection guidance: `docs/release-gates.md`.

## Quality, UI tests, and App Store release

Single entry point: **`docs/PRODUCTION_TEST_AND_RELEASE_RUNBOOK.md`** (unit vs UI tests, scripts, App Store checklist links, bundle ID note).

- Full local suite (erases simulators): `bash scripts/run-stable-tests.sh`
- UI tests only: `bash scripts/run-ui-tests-only.sh` (run `chmod +x scripts/run-ui-tests-only.sh` once if needed)
- Focused unit checks: `bash scripts/run-investor-ui-tests.sh`

## Docs

- Manual QA (lesson video backup + YouTube companion): `docs/MANUAL_TESTING_MODULE_VIDEO_AND_YOUTUBE.md`
- Local API keys template: `LocalSecrets.xcconfig.example` → `LocalSecrets.xcconfig` (gitignored)
