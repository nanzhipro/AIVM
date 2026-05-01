# Phase 6: Error recovery and local diagnostics

## Phase Contract

本 phase 交付本机错误恢复和诊断入口：当 ISO、配置或 lifecycle 状态需要处理时，用户可以重新选择 ISO、重试启动、查看本机日志目录，并生成隐私克制的本地诊断摘要。本 phase 不引入远端上传、guest agent 或高级恢复策略。

## PHASE_CONTRACT:FACT_AUDIT

- `Error` 是可恢复状态；不得把错误态等同于删除 VM。
- 重新选择 ISO 只能在 `Draft` / `Stopped` / `Error` 且没有 active stop-required 状态时可用。
- 重新选择 ISO 必须重新走 `AdmissionPolicy.evaluate(request:host:)`；失败不得修改 metadata。
- 成功替换 ISO 后，metadata 必须保存新的 install media path、`bootSource = InstallMedia`，并回到可重新启动的本地状态。
- 本地诊断报告只允许记录 app/host/VM metadata 摘要、bundle artifact 存在性和资源数字；不得记录 guest 屏幕、键盘输入、guest 文件内容或底层堆栈。
- 日志/诊断入口只操作当前 VM bundle 的 `logs/` 目录，不能触碰 bundle 外部路径。
- UI 必须用本地化短文案表达恢复动作，不显示 Virtualization.framework 类型名或异常栈。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMHomeViewModel.replaceInstallMedia(from:)` | Detail recovery ISO button / importer | Current VM can replace install media | Admission blockers preserve existing metadata |
| `VMDiagnosticsManager` | `VMHomeViewModel.openDiagnostics()` | User chooses the logs action | Write/open failures leave VM state untouched |
| Diagnostics snapshot writer | `VMDiagnosticsManager.writeSnapshot` | Logs action executes for current metadata | Existing logs directory is created if missing |
| Error recovery banner | `RootView` detail surface | Metadata state is `Error` or configuration readiness failed | Non-error states show normal details only |

## Scope

Must implement:

- A diagnostics provider that writes a local privacy-safe JSON snapshot into the VM bundle `logs/` directory.
- A view-model method to open the current diagnostics directory using AppKit `NSWorkspace` after writing the snapshot.
- A view-model method to replace install media for recoverable states using existing admission policy and store persistence.
- Detail UI recovery controls for choose ISO, retry/start, and view logs when appropriate.
- Localized copy for diagnostics and recovery labels in `en`, `zh-Hans`, and `ja`.
- `scripts/audit_diagnostics_privacy.rb` to statically prove local-only diagnostics, no guest content collection, and UI wiring.
- XCTest coverage for diagnostics snapshot contents, ISO replacement success/failure, and view-model diagnostics wiring with fakes.

Must not implement:

- Remote upload, telemetry, crash reporting, cloud sync, support ticket submission, or external diagnostics services.
- Guest-agent integration, guest filesystem inspection, screen capture, keyboard capture, packet capture, or log scraping from inside the VM.
- Automatic install completion detection, automatic repair, snapshots, rollback, or VM cloning.
- Destructive recovery beyond the existing explicit delete VM action.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required evidence before completion:

- `ruby scripts/planctl lint-contracts --phase phase-6-errors-diagnostics` passes.
- `ruby scripts/audit_diagnostics_privacy.rb` passes.
- `ruby scripts/audit_localizations.rb` passes.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` passes.
- XCTest proves diagnostics are written under `logs/` and omit full install media paths.
- XCTest proves rejected ISO replacement does not mutate persisted metadata.

## PHASE_CONTRACT:FAILURE_MODES

- Invalid replacement ISO leaves existing metadata unchanged and exposes localized admission blockers.
- Diagnostics write/open failure does not alter VM state.
- Missing metadata makes diagnostics and replacement actions unavailable.
- Error recovery controls do not bypass lifecycle state-machine permissions.
- Privacy audit fails if diagnostics code references guest screen/input/file capture concepts or remote upload behavior.

## Completion Criteria

- Recoverable detail UI exposes choose ISO, retry/start, and view logs actions with localized copy.
- Diagnostics snapshot is local-only and privacy-safe by construction and audit.
- Required checks in `plan/manifest.yaml` pass.
