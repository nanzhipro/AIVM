# Phase 5: Create, detail, and VM run UI

## Phase Contract

本 phase 交付 AIVM 的主用户界面闭环：用户能从 ISO 创建单台 VM，在详情页查看资源与状态，通过按钮启动/停止 VM，并在运行区域看到 Apple Virtualization console 容器。本 phase 使用已有 admission、bundle store、configuration builder 和 lifecycle controller，不改变底层 VM 策略。

## PHASE_CONTRACT:FACT_AUDIT

- MVP 只管理一台本地 VM；若已有 metadata，创建入口不可再创建第二台。
- 创建 VM 必须从用户选择的 `.iso` 文件开始，并通过 `AdmissionPolicy.evaluate(request:host:)` 才能写入 bundle metadata。
- 新建 VM 的默认资源使用 phase-1 定义的 `VMResourceConfiguration.standard`，网络模式固定 `NAT`，启动源为 `InstallMedia`，状态为 `Draft`。
- 详情 UI 必须呈现 VM 名称、产品状态、CPU、内存、磁盘、启动介质和网络模式，不展示底层异常栈或 API 类型名。
- 启动/停止按钮必须调用 `VMHomeViewModel.startCurrentVM()` / `stopCurrentVM()`，不得直接操作 `VZVirtualMachine`。
- Console UI 必须使用 `VZVirtualMachineView` 包装层，并只绑定 lifecycle controller 暴露的 active VM；没有 active VM 时显示本地占位区域。
- 删除动作只能调用 `VMBundleStore.deleteBundle(for:)` 删除当前 VM bundle，不能触碰 bundle 根目录之外的路径。
- 所有新增用户可见字符串必须进入 `en`、`zh-Hans`、`ja` 三套 `Localizable.strings`，保持短句、动作导向、无过程语言。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `RootView` create/detail/run surface | App `WindowGroup` | App launches and metadata is loaded | Host blockers disable create/start and show localized recovery text |
| `VMHomeViewModel.createVM(from:)` | ISO file importer handler | User selects a local ISO | Admission blockers prevent bundle creation and preserve previous metadata |
| `VMHomeViewModel.startCurrentVM()` / `stopCurrentVM()` | Start/stop buttons | Loaded metadata and state machine allow the action | Failures reload persisted metadata and keep user on detail view |
| `VirtualMachineConsoleView` | VM detail run panel | Lifecycle exposes an active `VZVirtualMachine` | No active VM renders a localized placeholder, not a fake console |
| `VMBundleStore.deleteBundle(for:)` | Delete confirmation action | User confirms deletion of current VM | Delete failures leave current metadata loaded |

## Scope

Must implement:

- SwiftUI create flow using a macOS file importer limited to ISO-like files.
- View-model create/delete methods that use existing store, admission policy, and lifecycle state rules.
- Detail UI with concise localized labels for state, resources, ISO, network, and available actions.
- Start/stop controls wired only through `VMHomeViewModel` lifecycle methods.
- A `VZVirtualMachineView` representable used in the run area, with a placeholder when no active VM is available.
- Localized copy additions in `en`, `zh-Hans`, and `ja`.
- Unit/UI-oriented tests covering create admission, delete, button availability, and view model action wiring.

Must not implement:

- Multi-VM navigation, VM list management, snapshots, pause/resume, save/restore, bridged networking, shared folders, clipboard, USB, audio, or Rosetta.
- Installation-complete auto-detection, reboot detection, guest-agent integration, or guest filesystem inspection.
- Diagnostics export, log opening behavior, or detailed error recovery beyond existing localized summaries.
- New process-language UI copy or direct display of Virtualization.framework errors.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required evidence before completion:

- `ruby scripts/planctl lint-contracts --phase phase-5-vm-ui` passes.
- `ruby scripts/audit_localizations.rb` passes.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` passes.
- XCTest proves create/delete metadata behavior and start/stop UI action surfaces without booting a real guest.
- UI code statically contains a production `VZVirtualMachineView` wrapper and action buttons wired through the view model.

## PHASE_CONTRACT:FAILURE_MODES

- Host or ISO admission blockers prevent VM creation and expose localized recovery copy.
- Selecting an invalid file does not create or mutate bundle metadata.
- Start/stop failures rely on phase-4 persistence behavior and reload the detail view.
- Deletion failure keeps the existing metadata visible and does not remove unrelated files.
- Missing active VM leaves the console area in a localized placeholder state.

## Completion Criteria

- Root UI supports create, detail, start, stop, console placeholder/attachment, and delete for one VM.
- Newly added user-visible copy is localized in all required locales and passes localization audit.
- Required checks in `plan/manifest.yaml` pass.
