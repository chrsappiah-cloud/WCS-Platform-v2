# Required CI checks (branch protection)

Enable these on `main` and `test/ios-strict-quality-gates` in GitHub → **Settings → Branches → Branch protection rules**:

| Required check | Workflow | Job |
|----------------|----------|-----|
| CI Build and Test | `iOS CI/CD` | `ci-build-and-test` |

Steps enforced:

1. Validate support contacts (`scripts/validate-support-contacts.sh`)
2. Validate external link allowlist
3. Simulator build
4. `WCS-PlatformTests` (unit + integration)
5. UI smoke (`Smoke`, `ReviewFlows`, `Recovery`)
6. Full UI E2E (`WCS-PlatformUITests/E2E`)
7. Privacy manifest present

Optional weekly: `iOS UI Tests` workflow (`workflow_dispatch` / cron).
