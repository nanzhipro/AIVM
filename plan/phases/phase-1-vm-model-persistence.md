# Phase 1: VM model and bundle persistence

## 阶段定位

建立单 VM 的产品层数据模型与本地 bundle 持久化能力，让应用启动时能恢复唯一 VM 的元数据与目录布局，为后续准入检查、Virtualization 配置和生命周期状态机提供稳定存储基础。

## 必带上下文

- plan/common.md
- plan/phases/phase-1-vm-model-persistence.md
- plan/execution/phase-1-vm-model-persistence.md

## 阶段目标

- 定义 `Draft`、`Installing`、`Stopped`、`Running`、`Error` 五种产品状态以及 ISO / disk 启动源、NAT 网络模式。
- 定义 VM 元数据 schema，包含 schema version、稳定 VM ID、显示名称、ISO 路径、启动源、网络模式、状态、资源配置和时间戳。
- 建立固定 bundle 根目录与布局：`~/Library/Application Support/phas/VMs/<vm-id>.vmbundle/`，并暴露 `config.json`、`Disk.img`、`MachineIdentifier`、`NVRAM`、`logs/` 的规范路径。
- 实现安全的 bundle 创建、元数据保存/加载、单 VM 枚举和 bundle 删除能力。
- 将 root app shell 接到真实 store，启动时读取已有 VM 元数据，但不提供创建向导或真实 VM 启动。
- 提供 schema 审计脚本和 XCTest，证明 schema、目录布局和基本持久化行为可重复。

## 实施范围

- AIVM app module 内的 VM metadata、resource configuration、bundle layout、bundle store 和 root shell 读取入口。
- AIVMTests 内的 Codable、layout、create/load/delete 单元测试。
- Xcode project 更新和 `scripts/audit_vm_bundle_schema.rb`。

## 本阶段产出

- 可 Codable 往返的 `VMMetadata` 与相关枚举/资源配置。
- 可在测试目录中创建、读取、更新、枚举、删除 VM bundle 的 `VMBundleStore`。
- app shell 启动时使用 production store 加载本地 VM 元数据。
- schema/layout 审计脚本和单元测试。

## 明确不做

- 不创建真实虚拟磁盘内容或调用 `VZDiskImageStorageDeviceAttachment`。
- 不生成真实 `VZGenericMachineIdentifier` 或 EFI variable store。
- 不执行宿主机资源准入检查、ISO 架构检查或磁盘空间策略。
- 不构建 `VZVirtualMachineConfiguration`，不启动 `VZVirtualMachine`，不显示 `VZVirtualMachineView`。
- 不实现创建向导、生命周期动作、诊断导出或删除确认 UI。

## PHASE_CONTRACT:FACT_AUDIT

- 真实入口：AIVM root shell view model 在 app 启动时通过 `VMBundleStore` 读取现有 VM metadata。
- 真实调用方：SwiftUI root scene、AIVMTests、schema audit script。
- target / 打包归属：`AIVM` macOS app target、`AIVMTests`、repository scripts。
- 证据命令：`ruby scripts/audit_vm_bundle_schema.rb`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| `VMMetadata` schema | AIVM model layer | bundle store and app shell view model | App loads or saves VM config | invalid schema throws and preserves files | Codable and schema tests pass | phase-1-vm-model-persistence |
| `VMBundleLayout` | AIVM persistence layer | bundle store | VM bundle path is needed | path validation rejects unsafe targets | layout tests and schema audit pass | phase-1-vm-model-persistence |
| `VMBundleStore` | AIVM persistence layer | root app shell view model | App launches or tests create a VM | load failure returns no VM to UI, deletion is scoped to bundle | create/load/delete tests pass | phase-1-vm-model-persistence |
| root shell metadata loading | AIVM app shell | SwiftUI scene hierarchy | App launches | empty state remains visible | macOS build/test passes | phase-1-vm-model-persistence |
| `scripts/audit_vm_bundle_schema.rb` | repository script | planctl required check | Phase completion runs required checks | completion exits 2 | vm-bundle-schema-audit passes | phase-1-vm-model-persistence |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- `ruby scripts/audit_vm_bundle_schema.rb` proves required state names, schema version and bundle filenames are present in source.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` proves model, store, root shell loading and tests compile and pass.
- Unit tests create bundle data in a temporary directory, proving production file operations without touching the real user Application Support path.

## PHASE_CONTRACT:FAILURE_MODES

- 冷启动 / 重启：missing or invalid config must not crash the app shell; the shell falls back to the existing empty state.
- 超时 / late reply：build/test or schema audit timeout blocks completion and leaves state unchanged.
- 并发 / 重复触发：re-running create/load/delete tests uses isolated temporary roots and does not touch user data.
- 配置关闭 / 空状态 / fallback：no persisted VM means the empty state stays visible; malformed metadata is rejected rather than silently repaired.
- 删除安全：delete operation is scoped to `<vm-id>.vmbundle` under the configured root and must not remove arbitrary paths.

## 完成判定

- `ruby scripts/planctl lint-contracts --phase phase-1-vm-model-persistence` 返回 0。
- `ruby scripts/audit_vm_bundle_schema.rb` 返回 0。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- Tests 证明 `config.json` 可保存/加载、bundle layout 使用固定路径和文件名、删除只移除对应 bundle。
- Root app shell 通过真实 store 读取持久化 VM 元数据，且无 VM 时仍展示既有空状态。

## 依赖关系

- depends_on: phase-0-app-shell-i18n
