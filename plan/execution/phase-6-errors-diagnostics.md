# Phase 6 执行包

## PHASE_CONTRACT:FACT_AUDIT

本执行包落实 `phase-6-errors-diagnostics`：在 phase 5 UI 上增加错误恢复和本地诊断。实现只使用本机 bundle/logs 目录、Foundation、AppKit、OSLog 和 XCTest，不增加远端依赖。

## Allowed Paths

- `plan/phases/phase-6-errors-diagnostics.md`
- `plan/execution/phase-6-errors-diagnostics.md`
- `AIVM.xcodeproj/**`
- `AIVM/**`
- `AIVMTests/**`
- `AIVMUITests/**`
- `scripts/audit_diagnostics_privacy.rb`
- `scripts/audit_localizations.rb`

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMDiagnosticsManager` | `VMHomeViewModel.openDiagnostics()` | User taps localized logs action | Errors are logged and metadata remains loaded |
| `VMDiagnosticSnapshot` | `VMDiagnosticsManager.writeSnapshot` | Diagnostics directory is opened | Snapshot omits full host ISO path and guest content |
| `VMHomeViewModel.replaceInstallMedia(from:)` | Root detail ISO recovery action | Current metadata exists and state allows replacement | Admission failure stores decision and leaves metadata untouched |
| Recovery banner/actions | `RootView` detail view | VM state is `Error` or readiness failed | Normal states keep standard action bar only |

## Implementation Steps

1. Add diagnostics provider types in `AIVM/` with JSON snapshot writing under `VMBundleLayout.logsURL(for:)`.
2. Wire `VMHomeViewModel` with diagnostics provider injection, `openDiagnostics()`, `canReplaceInstallMedia`, and `replaceInstallMedia(from:)`.
3. Update `RootView` file importer routing so empty state creates a VM and detail recovery replaces install media.
4. Add localized diagnostics/recovery labels and keep all copy free of banned process terms.
5. Add tests for diagnostics snapshot privacy, diagnostics directory creation, replacement ISO success/failure, and view-model action availability.
6. Add `scripts/audit_diagnostics_privacy.rb` for local-only diagnostics and no guest content capture checks.
7. Run required checks and complete only after they pass.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required commands:

```bash
ruby scripts/planctl lint-contracts --phase phase-6-errors-diagnostics
ruby scripts/audit_diagnostics_privacy.rb
ruby scripts/audit_localizations.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Expected runtime evidence:

- XCTest verifies diagnostics snapshot file is created under the current VM bundle `logs/` directory.
- XCTest verifies snapshot contains VM ID/state/resource summary and install media file name, not full install media path.
- XCTest verifies valid replacement ISO updates metadata and invalid replacement ISO does not mutate metadata.
- XCTest verifies `openDiagnostics()` is injectable and does not require opening Finder in tests.

## PHASE_CONTRACT:FAILURE_MODES

- Diagnostics write/open error: logged locally; no metadata mutation.
- Missing metadata: diagnostics and replacement no-op.
- Invalid replacement ISO: no metadata mutation and admission decision remains visible.
- Replacement attempted while VM is `Installing` or `Running`: no-op to preserve lifecycle state rules.
- Audit blocks remote upload, guest screen/input/file capture tokens, and diagnostics outside `logs/`.

## Done Checklist

- Formal contract lint passes.
- Diagnostics provider is production-wired through `VMHomeViewModel` and `RootView`.
- ISO recovery is admission-gated and state-gated.
- All new user-visible copy is localized in `en`, `zh-Hans`, and `ja`.
- Required checks in manifest pass.
