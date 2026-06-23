# WCS iOS Intensive Testing Kit

This testing kit extracts the concepts and themes from iOS Unit Testing by Example and turns them into a practical production-readiness standard for World Class Scholars iOS apps.

## Chapter themes

### Part I: Foundations
- Assertions, test naming, and the meaning of a unit test.
- Test lifecycle, setUp, tearDown, and the AAA structure.
- Code coverage, characterization tests, and safe progress on legacy code.
- App launch control and isolating view controllers.
- Managing difficult dependencies with fakes, spies, mocks, and dependency injection.

### Part II: iOS testing tips and techniques
- Outlet connections, button taps, alerts, and navigation.
- Testing UserDefaults, network requests, asynchronous responses, and closures.
- Text fields, delegate methods, input focus, table views, and snapshots.

### Part III: Using your new power
- Refactoring safely with tests.
- Moving from MVC to MVVM and MVP.
- Applying TDD to drive new code design.

## Production testing scope

### 1. Assertion discipline
Use the right assertion for the behavior under test. Prefer clear failures, avoid redundant messages, and keep tests readable. Use equality tests for state, Boolean assertions for conditions, and explicit failure only when the test truly cannot continue.

### 2. Test lifecycle discipline
Treat each test as a clean room. Put shared setup in setUp, clean up in tearDown, and avoid shared mutable state that leaks between tests. Use Test Zero when creating a new suite so you know the test wiring works before adding behavior.

### 3. Coverage discipline
Turn on code coverage early and use it to find gaps, not as a vanity metric. Cover conditions, loops, and sequential statements with enough tests to prove behavior at the boundaries. Add characterization tests for legacy code before changing it.

### 4. View controller discipline
Load storyboards, XIBs, and code-based controllers under test. Verify outlets, actions, alerts, and navigation without depending on the full app flow. When a view needs a real window or hierarchy, add it explicitly so focus and responder behavior works.

**WCS SwiftUI mapping:** treat `ViewModels` as controllers; use UI tests for view wiring and `ViewModels/*Tests` for state/navigation intent.

### 5. Dependency discipline
Isolate difficult dependencies behind protocols or boundaries. Use dependency injection for network sessions, storage, factories, singleton access, and closures that create objects. Prefer fakes for stateful replacements, spies for observation, and mocks for strict verification.

### 6. UIKit interaction discipline
Test button taps through actions, alerts through verifiers, text fields through their delegates, and tables through data source and delegate calls. Keep helpers small and reusable so tests stay expressive.

### 7. Appearance discipline
Use snapshot tests for layout and rendering changes. Lock reference images for critical screens like onboarding, login, dashboards, and content-entry forms so unplanned UI drift is caught early.

### 8. Refactoring discipline
Refactor in small verified steps. Use tests as your safety net while moving behavior between objects or changing architecture. Verify behavior after every move, especially when extracting presenters, view models, and helper types.

## WCS module checklist

| Area | What to test |
|---|---|
| App startup | Launch path, initial controller, scene/app delegate behavior |
| Forms | Text entry, return-key behavior, validation, focus changes |
| Navigation | Push, modal, segue, and dismissal flows |
| Storage | Defaults, persistence, recovery, and empty-state behavior |
| Networking | Requests, responses, async completions, errors, retries |
| Tables | Row count, cell content, row selection, updates |
| Alerts | Message text, button wiring, cancel/confirm behavior |
| Appearance | Layout, snapshot comparisons, device variations |
| Refactoring safety | Tests that protect extracted types and moved logic |

## WCS Apple Store readiness criteria

A feature is ready only when it has:
- Direct unit tests for core logic.
- View controller tests for UI behavior.
- Dependency isolation for external services.
- Coverage for edge cases and failure paths.
- Snapshot or UI checks for critical appearance.
- CI execution with green results.
- Safe refactoring coverage before structural changes.

## Test design rules

1. Write a failing test first for new behavior.
2. Keep each test focused on one behavior.
3. Prefer stable, fast, deterministic tests.
4. Use helpers to remove repetition, but do not hide intent.
5. Add tests before changing legacy code.
6. Test both success and failure states.
7. Verify the thing the user experiences, not just implementation details.

## Suggested suite structure

- AppLaunchTests
- AssertionTests
- LifecycleTests
- CoverageTests
- StartupControllerTests
- NavigationTests
- StorageTests
- NetworkRequestTests
- NetworkResponseTests
- TextFieldTests
- TableViewTests
- AlertTests
- SnapshotTests
- RefactoringSafetyTests

## WCS-Platform implementation map

| Intensive suite | WCS-Platform location |
|---|---|
| AppLaunchTests | `WCS-PlatformUITests/Smoke/AppLaunchProductionTests.swift` |
| AssertionTests | `WCS-PlatformTests/Models/*` (equality + decode assertions) |
| LifecycleTests | `WCS-PlatformTests/Unit/AppLaunchConfigurationTests.swift` |
| CoverageTests | `project.yml` (`gatherCoverageData: true`) + CI |
| StartupControllerTests | `WCS-PlatformTests/ViewModels/AppViewModelTests.swift` |
| NavigationTests | `WCS-PlatformUITests/E2E/TabNavigationE2ETests.swift` |
| StorageTests | `AuthTokenPersistenceTests`, `LearningPersistenceIntegrationTests` |
| NetworkRequestTests | `NetworkClientOfflineTests`, `AuthTokenPersistenceTests` |
| NetworkResponseTests | `NetworkChaosHarnessTests`, decode tests in `WCS_PlatformTests` |
| TextFieldTests | `AdminCourseCreatorViewModelTests`, `ManualBackupAuthoringE2ETests` |
| TableViewTests | Catalog/list flows in `WCS_PlatformUITests` (Programs tab) |
| AlertTests | Admin publish/regenerate alerts (UI harness, manual pass) |
| SnapshotTests | `WCS_PlatformUITestsLaunchTests` |
| RefactoringSafetyTests | `domainContracts_haveStrictSingleOwnership` + integration publish tests |

## Practical WCS checklist

- Every screen loads in a test without the full app running.
- Every important button, field, and cell has a test.
- Every network request has at least one success and one failure test.
- Every persistence path has save and reload coverage.
- Every critical journey has a UI or snapshot test.
- Every legacy module gets characterization tests before changes.
- Every release passes CI with test coverage enabled.

## Commands

```bash
# Full production + intensive kit (simulator)
./scripts/run-production-test-kit.sh

# Units only (76+ tests)
xcodebuild -project WCS-Platform/WCS-Platform.xcodeproj -scheme WCS-Platform \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WCS-PlatformTests test
```
