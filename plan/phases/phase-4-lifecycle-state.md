# Phase 4: VM lifecycle and state machine

## Phase Contract

本 phase 交付 VM lifecycle orchestration：在 phase-3 已验证配置之上创建 `VZVirtualMachine`、执行启动/停止请求、持久化产品状态，并把可用动作暴露给 root view model。当前 phase 不交付 VM console UI，也不实现安装完成自动识别。

## PHASE_CONTRACT:FACT_AUDIT

- 产品状态只允许 `Draft`、`Installing`、`Stopped`、`Running`、`Error`。
- `Draft` / `Stopped` / `Error` 可尝试启动；`Installing` / `Running` 可尝试停止。
- 从 install media 启动成功后进入 `Installing`；从 disk 启动成功后进入 `Running`。
- 停止成功后进入 `Stopped`；启动或停止失败后进入 `Error`，并保留 bundle 数据。
- phase 3 已提供 `VMConfigurationBuilder`，本 phase 必须使用它生成 VZ 配置，不得绕过配置构造层。
- 当前 phase 可以实例化和操作 `VZVirtualMachine`，但不得接入 `VZVirtualMachineView` 或构建 console UI。
- 不依赖 guest agent，不读取 guest 内部文件，不自动判断安装完成。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMStateMachine` | `VMHomeViewModel` and lifecycle tests | Metadata state changes or actions are evaluated | Invalid transitions are rejected without mutating metadata |
| `VMLifecycleController` | `VMHomeViewModel.startCurrentVM()` / `stopCurrentVM()` | User-facing action methods are invoked by current or future UI | Failure persists `Error` and leaves bundle intact |
| `VZVirtualMachineAdapter` | `VMLifecycleController` default factory | Real lifecycle operation requires a Virtualization VM instance | Tests inject fake machines; production uses real `VZVirtualMachine` |

## Scope

Must implement:

- Pure state-machine rules for start/stop permissions and target states.
- A lifecycle controller that builds configuration through `VMConfigurationBuilder`, creates a `VZVirtualMachine`, starts/stops it, and persists updated `VMMetadata`.
- A small virtual-machine adapter protocol so tests never need to boot a real guest.
- Root view model action/readiness properties for start and stop availability.
- Local OSLog lifecycle events for start, stop, and failure summaries.
- Unit tests covering valid transitions, invalid transitions, start success/failure, stop success/failure, metadata persistence, and view model action wiring.
- `scripts/audit_lifecycle_state.rb` to statically prove lifecycle wiring and state coverage.

Must not implement:

- VM display embedding or `VZVirtualMachineView`.
- Create-form UI, detail UI, or localized action copy beyond existing keys.
- Installation-complete detection, reboot detection, snapshot/save-restore, pause/resume, or guest-agent integration.
- Destructive VM deletion.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required evidence before completion:

- `ruby scripts/planctl lint-contracts --phase phase-4-lifecycle-state` passes.
- `ruby scripts/audit_lifecycle_state.rb` passes.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` passes.
- XCTest proves lifecycle actions update persisted metadata without launching a real VM by using fake adapters.

## PHASE_CONTRACT:FAILURE_MODES

- Invalid state transitions throw typed lifecycle errors and do not mutate metadata.
- Configuration builder failures persist `Error` and are rethrown to the caller.
- VM start/stop failures persist `Error` and keep the bundle on disk.
- If no active VM exists for a stop request, the controller rejects the operation instead of fabricating a stopped state.
- View model action methods swallow no failures silently: they reload persisted metadata after lifecycle attempts.

## Completion Criteria

- Production lifecycle controller exists and is injected into `VMHomeViewModel`.
- `VMHomeViewModel` exposes start/stop availability and async action methods.
- Required checks in `plan/manifest.yaml` pass.
