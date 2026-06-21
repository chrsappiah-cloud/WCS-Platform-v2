# Required CI checks (branch protection)

Enable these on `main` and `test/ios-strict-quality-gates` in GitHub → **Settings → Branches → Branch protection rules**:

| Required check | Workflow | Job |
|----------------|----------|-----|
| CI Build and Test | `iOS CI/CD` | `ci-build-and-test` |

Steps enforced:

1. Validate support contacts (`scripts/validate-support-contacts.sh`)
2. Validate external link allowlist
3. Verify no IAP/payment/subscription references in source/UI/test code
4. Simulator build
5. `WCS-PlatformTests` (unit + integration)
6. UI smoke (`Smoke`, `ReviewFlows`, `Recovery`)
7. Full UI E2E (`WCS-PlatformUITests/E2E`)
8. Manual video backup E2E (`ManualBackupAuthoringE2ETests`)
9. Privacy manifest present

Optional weekly: `iOS UI Tests` workflow (`workflow_dispatch` / cron).
