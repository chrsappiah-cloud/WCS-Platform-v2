# ARC Shield Implementation (WCS Platform)

This repository implements ARC Shield using the current app architecture and synchronized Xcode targets.

## Implemented Layers

1. **Spec Guard**
   - `production/apple/ARC_SHIELD_SUBMISSION_CHECKLIST.md`
   - `production/apple/ARC_SHIELD_REGRESSION_LEDGER.md`
2. **TDD Core**
   - `WCS-PlatformTests/Unit/AppLaunchConfigurationTests.swift`
   - `WCS-PlatformTests/Unit/NetworkChaosHarnessTests.swift`
   - `WCS-PlatformTests/Unit/PermissionPolicyMatrixTests.swift`
3. **Review Flow Harness**
   - `WCS-PlatformUITests/Smoke/SmokeReviewFlowTests.swift`
   - `WCS-PlatformUITests/ReviewFlows/ReviewCriticalPathUITests.swift`
   - `WCS-PlatformUITests/Recovery/RecoveryFlowUITests.swift`
4. **Regression Ledger**
   - `production/apple/ARC_SHIELD_REGRESSION_LEDGER.md`
5. **Runtime Probe and launch controls**
   - `WCS-Platform/TestingSupport/LaunchArguments/AppLaunchConfiguration.swift`
   - `WCS-Platform/TestingSupport/LaunchArguments/AppLaunchEnvironmentBootstrapper.swift`
   - `WCS-Platform/WCS_PlatformApp.swift` bootstrap call

## Supported Launch Arguments

- `-uiTestMode`
- `-mockNetwork offline|online`
- `-mockPermissions deniedCamera`
- `-mockStoreKit productsFailure`
- `-seedEmptyDatabase`
- `-seedExpiredToken`
- `-seedMigratedState`

## Notes

- The project uses Xcode file-system-synchronized groups, so these files are auto-included in existing targets.
- Existing test suites remain intact and are extended by ARC Shield suites under `Unit`, `Smoke`, `ReviewFlows`, and `Recovery`.
