# Phase 4 执行包

## PHASE_CONTRACT:FACT_AUDIT

本执行包落实 `phase-4-lifecycle-state`：在 validated VZ configuration 上实现 lifecycle controller 和纯状态机。它不交付 UI console，也不启动测试中的真实 guest。

## Allowed Paths

- `plan/phases/phase-4-lifecycle-state.md`
- `plan/execution/phase-4-lifecycle-state.md`
- `AIVM.xcodeproj/**`
- `AIVM/**`
- `AIVMTests/**`
- `scripts/audit_lifecycle_state.rb`

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMStateMachine` | `VMHomeViewModel.canStartVM` / `canStopVM` | Metadata is loaded or changed | No metadata means actions unavailable |
| `VMLifecycleController` | `VMHomeViewModel.startCurrentVM()` / `stopCurrentVM()` | Start/stop action method is invoked | Errors are persisted as `Error` and metadata is reloaded |
| `VZVirtualMachineAdapter` | `VMLifecycleController` production factory | Builder returns a valid VZ configuration | Tests inject fake adapters; no real guest boot in required checks |

## Implementation Steps

1. Add lifecycle/state-machine code in `AIVM/`, using Virtualization and OSLog only.
2. Add `VMLifecycleControlling` and `VirtualMachineOperating` protocols for injection.
3. Implement real `VZVirtualMachineAdapter` over `VZVirtualMachine.start()` and `stop(completionHandler:)`.
4. Wire `VMHomeViewModel` with lifecycle controller, `canStartVM`, `canStopVM`, `startCurrentVM()`, and `stopCurrentVM()`.
5. Add unit tests with fake builder and fake virtual machines; do not boot real VMs.
6. Add `scripts/audit_lifecycle_state.rb` for state coverage, Virtualization usage, OSLog usage, and view-model wiring.
7. Run required checks and complete only after they pass.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required commands:

```bash
ruby scripts/planctl lint-contracts --phase phase-4-lifecycle-state
ruby scripts/audit_lifecycle_state.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Expected runtime evidence:

- XCTest covers `Draft` / `Stopped` / `Error` start permission and `Installing` / `Running` stop permission.
- XCTest verifies install-media start persists `Installing` and disk start persists `Running`.
- XCTest verifies stop persists `Stopped` and failures persist `Error`.
- XCTest verifies VMHomeViewModel action availability and async action wiring through injected fakes.

## PHASE_CONTRACT:FAILURE_MODES

- Invalid transition: typed error, no metadata mutation.
- Builder failure: state becomes `Error`, error rethrows.
- Start/stop failure: state becomes `Error`, error rethrows.
- Stop without active VM: typed error, no fabricated success.
- Build artifacts remain ignored and no VM bundle is deleted.

## Done Checklist

- Formal contract lint passes.
- Lifecycle code is production-wired through `VMHomeViewModel`.
- Required state transitions and failure modes have unit tests.
- Required checks in manifest pass.
