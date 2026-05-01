# AIVM Release Readiness

This document is the operator handoff for the AIVM MVP release candidate.

## Supported Scope

- Host: Apple silicon Mac, macOS 14 or newer.
- Guest: one local ARM64 Linux VM; Ubuntu Desktop ARM64 LTS is the primary validation target.
- Storage: `~/Library/Application Support/phas/VMs/<vm-id>.vmbundle/`.
- Networking: NAT only.
- UI languages: `en`, `zh-Hans`, and `ja`.
- Runtime: Apple Virtualization.framework with `VZVirtualMachineConfiguration`, `VZVirtualMachine`, and `VZVirtualMachineView`.

## Automated Validation

Run these commands from the repository root before creating a release candidate:

```bash
ruby scripts/planctl lint-contracts --phase phase-7-release-validation
ruby scripts/audit_release_readiness.rb
ruby scripts/audit_localizations.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

The current automated suite covers:

- Localization key consistency across all supported locales.
- VM metadata schema, bundle layout, safe bundle deletion, and JSON round trips.
- Host, ISO, resource admission, and recovery action mapping.
- Virtualization configuration construction, persistent runtime artifacts, NAT device graph, and configuration readiness.
- Lifecycle state transitions, start/stop failure handling, and fake-VM action wiring.
- Create/detail/run UI view-model behavior, one-VM scope, VZ console wrapper compilation, delete, local diagnostics, and ISO recovery.

The automated suite does not prove a completed Ubuntu installation, a real guest desktop login, or long-running guest workload stability. Those remain manual release checks.

## Manual Release Checks

Before shipping, a human operator should verify:

- A real Ubuntu Desktop ARM64 LTS ISO can be selected on an Apple silicon Mac.
- The app creates a VM bundle in the expected Application Support location.
- The VM display appears after start and remains responsive during install.
- Stop, restart, retry, delete, and choose ISO actions behave as expected.
- Local diagnostics open the VM `logs/` directory and create `diagnostics.json` without full ISO paths.
- Product copy reads naturally in English, Simplified Chinese, and Japanese.

## Privacy Boundary

- Diagnostics stay local and are written under the current VM bundle `logs/` directory.
- Diagnostics include VM ID, product state, resource values, host summary, app version, artifact presence, and ISO file name.
- Diagnostics do not include guest screen content, keyboard input, guest files, packet captures, full ISO paths, or remote upload endpoints.

## Known Limitations

- Only one local VM is supported.
- Intel Macs and cross-architecture guests are out of scope.
- Bridged networking, shared folders, clipboard sharing, USB passthrough, audio, snapshots, cloning, and automatic ISO downloads are out of scope.
- Installation completion is not auto-detected; the user controls start, stop, and recovery actions.
- The unsigned XCTest host may skip the explicit `VZVirtualMachineConfiguration.validate()` entitlement probe while still validating the configuration shape.
- UI smoke checks require the UI test target to be included in the scheme or test plan before they can run.

## Human Decisions

The final decision stays with the release operator:

- Whether to ship, hold, or request another release candidate.
- Whether to create a git tag and external release notes.
- Whether to archive `plan/` after finalization or keep it as the project ledger.
- Whether to request security, compliance, legal, or design review.
- Whether to schedule manual Ubuntu install regression on each supported macOS version.

## Useful Commands

```bash
git status --short --branch
git log --oneline -8
ruby scripts/planctl finalize
```

Run `finalize` only after all phases are completed and `planctl advance --strict` returns `ACTION: finalize`.