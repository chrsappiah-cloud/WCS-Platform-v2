# WCS iOS Production Test Kit

Production testing standard for **WCS-Platform**, mapped from unit → model → controller → network → integration → UI → CI.

Companion intensive standard (book-themed): [WCS_iOS_Intensive_Testing_Kit.md](./WCS_iOS_Intensive_Testing_Kit.md) and [WCS_iOS_Intensive_Testing_Kit.pdf](./WCS_iOS_Intensive_Testing_Kit.pdf).

## Layer mapping (SwiftUI app)

| Book layer | WCS implementation | Test location |
|---|---|---|
| Model | `Models/` | `WCS-PlatformTests/Models/` |
| Controller | `ViewModels/` + `Views/` | `WCS-PlatformTests/ViewModels/` |
| Network | `Network/` | `WCS-PlatformTests/Network/` + `Unit/NetworkChaosHarnessTests` |
| Integration | Repositories + stores | `WCS-PlatformTests/Integration/` |
| UI | Critical journeys | `WCS-PlatformUITests/{Smoke,ReviewFlows,Recovery,E2E,UI}/` |
| Release gates | CI + coverage | `.github/workflows/ios-ci-cd.yml` |

## Must-have suite (implemented)

- [x] App launch smoke — `AppLaunchProductionTests`
- [x] Authentication/session — `AuthenticationSessionUITests` + `AuthTokenPersistenceTests`
- [x] Core model tests — `UserModelTests`, `CourseModelTests`, `SubscriptionModelTests`
- [x] Form validation — `AdminCourseCreatorViewModelTests`
- [x] Save/publish flow — `ContentPublishIntegrationTests`
- [x] Offline/error paths — `NetworkClientOfflineTests`, `NetworkChaosHarnessTests`
- [x] Token persistence — `AuthTokenPersistenceTests`
- [x] UI smoke + E2E tabs, AI video, Apple payments — `WCS-PlatformUITests/E2E/`

## TDD workflow (per feature)

1. Write a failing test for one behavior.
2. Implement the smallest passing change.
3. Refactor while keeping tests green.
4. Add integration coverage when modules connect.
5. Add UI tests only for high-value / high-risk journeys.

## Commands

```bash
# Full production kit (simulator)
./scripts/run-production-test-kit.sh

# Units only
xcodebuild -project WCS-Platform/WCS-Platform.xcodeproj -scheme WCS-Platform \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WCS-PlatformTests test

# UI smoke + E2E
xcodebuild -project WCS-Platform/WCS-Platform.xcodeproj -scheme WCS-Platform \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WCS-PlatformUITests test
```

## Release gate

PRs must pass:

1. `WCS-PlatformTests` (all layers)
2. CI build
3. Optional: `WCS-PlatformUITests` on simulator before release branch merge

Enable coverage in scheme (`gatherCoverageData: true`) and track regression via `ARC_SHIELD_REGRESSION_LEDGER.md`.
