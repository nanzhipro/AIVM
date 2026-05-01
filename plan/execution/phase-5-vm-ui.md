# Phase 5 执行包

## PHASE_CONTRACT:FACT_AUDIT

本执行包落实 `phase-5-vm-ui`：在已有 one-VM metadata、admission、configuration readiness 和 lifecycle controller 上交付 create/detail/run UI。当前 phase 可以引入 `VZVirtualMachineView`，但不得扩展 VM 平台能力或错误诊断范围。

## Allowed Paths

- `plan/phases/phase-5-vm-ui.md`
- `plan/execution/phase-5-vm-ui.md`
- `AIVM.xcodeproj/**`
- `AIVM/**`
- `AIVMTests/**`
- `AIVMUITests/**`
- `scripts/audit_localizations.rb`

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| ISO file importer in `RootView` | Header and empty-state create controls | User chooses create/select ISO | Invalid or cancelled selection leaves metadata unchanged |
| `VMHomeViewModel.createVM(from:)` | File importer completion | Admission allows selected ISO and host | Admission issues are stored and creation is rejected |
| `VMHomeViewModel.deleteCurrentVM()` | Delete confirmation button | Current metadata exists and user confirms | Delete errors preserve metadata and bundle state |
| `VirtualMachineConsoleView` | Detail run panel | `displayVirtualMachine` is non-nil | Placeholder explains no active display is attached |
| Start/stop buttons | Detail action bar | `canStartVM` / `canStopVM` true | Buttons disable when state or readiness disallows the action |

## Implementation Steps

1. Extend localization keys and all three locale files for create/detail/run labels, resources, start/stop, delete confirmation, and console placeholder copy.
2. Extend `VMLifecycleControlling` / adapter wiring if needed so the view model can expose the active `VZVirtualMachine` for display without tests launching a real guest.
3. Add `VirtualMachineConsoleView` as an `NSViewRepresentable` wrapper around `VZVirtualMachineView`.
4. Add `VMHomeViewModel.createVM(from:)`, delete support, admission issue state, and display VM state while keeping existing lifecycle injection testable.
5. Replace `RootView` placeholder buttons with a create/detail/run surface wired to view-model methods and file importer.
6. Add tests for create admission success/failure, delete behavior, and start/stop action availability with fakes.
7. Run localization audit and build/test before completion.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required commands:

```bash
ruby scripts/planctl lint-contracts --phase phase-5-vm-ui
ruby scripts/audit_localizations.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Expected runtime evidence:

- XCTest verifies a selected valid ARM64 ISO creates one `Draft` VM with `InstallMedia`, `NAT`, and standard resources.
- XCTest verifies blocked admission does not create metadata.
- XCTest verifies delete removes current bundle metadata from the view model.
- XCTest verifies view-model start/stop actions remain injectable and do not require a real guest.
- Build proves `VZVirtualMachineView` wrapper compiles in production UI code.

## PHASE_CONTRACT:FAILURE_MODES

- Cancelled importer: no state mutation.
- Invalid ISO or unsupported host: no bundle creation; localized admission issue remains available.
- Create after an existing VM: rejected to preserve one-VM scope.
- Start/stop unavailable: UI disables actions; direct view-model call returns without mutation.
- Delete failure: current metadata remains loaded; no external paths are touched.

## Done Checklist

- Formal contract lint passes.
- Create/detail/run UI is production-wired through `RootView` and `VMHomeViewModel`.
- `VZVirtualMachineView` exists only as the console wrapper, not as a test dependency.
- All new user-visible copy is localized in `en`, `zh-Hans`, and `ja`.
- Required checks in manifest pass.
