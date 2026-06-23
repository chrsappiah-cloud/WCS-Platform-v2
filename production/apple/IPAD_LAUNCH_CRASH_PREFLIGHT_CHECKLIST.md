# iPad Launch Crash Preflight Checklist

Run this checklist before every App Store resubmission after a launch-crash rejection.

## 1) Symbolication and triage

- [ ] Pull latest crash report from App Store Connect.
- [ ] Symbolicate against the exact uploaded build.
- [ ] Map to crash class (nil unwrap, missing resource, startup race, entitlement/config mismatch).
- [ ] Record root cause and owner in regression ledger.

## 2) Startup hardening validation

- [ ] Clean install launch on iPhone 17 Pro Max (physical).
- [ ] Clean install launch on iPad class (latest supported iPad simulator/device).
- [ ] Offline launch check.
- [ ] Relaunch after force-quit check.
- [ ] Background/foreground transition check.

## 3) Configuration sanity

- [ ] `Info.plist` keys resolved for release scheme.
- [ ] No missing runtime secrets cause early startup failure.
- [ ] Feature flags default to safe values when environment keys are absent.
- [ ] Crash/diagnostic logging enabled for startup path.

## 4) Automated tests

- [ ] `WCS-PlatformTests` pass in CI (strict mode enabled).
- [ ] `WCS-PlatformUITests` smoke/recovery pass.
- [ ] Targeted AI video + access flow E2E pass.
- [ ] Infrastructure health tests pass.

## 5) Review payload

- [ ] Resolution Center response updated (2.1(a) + 2.1(b)).
- [ ] Notes for Review updated for current build.
- [ ] Business model answers aligned to current monetization behavior.

