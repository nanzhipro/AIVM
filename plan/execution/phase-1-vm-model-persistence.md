# Phase 1 执行包

本文件不能单独使用。执行当前 phase 时，必须同时携带完整的 `plan/common.md` 和配对的 `plan/phases/phase-1-vm-model-persistence.md`。

## 必带上下文

- plan/common.md
- plan/phases/phase-1-vm-model-persistence.md
- plan/execution/phase-1-vm-model-persistence.md

## 执行目标

- 落地单 VM 的 Swift 数据模型、状态枚举、启动源和 NAT 网络模式。
- 落地固定 VM bundle 路径与文件名约定，并提供安全的 create/load/save/delete 操作。
- 将 app shell 接到真实 bundle store，启动时读取已有 VM metadata。
- 用 XCTest 和 `scripts/audit_vm_bundle_schema.rb` 验证 schema、layout 和持久化行为。

## 本次允许改动

- plan/phases/phase-1-vm-model-persistence.md
- plan/execution/phase-1-vm-model-persistence.md
- AIVM.xcodeproj/**
- AIVM/**
- AIVMTests/**
- scripts/audit_vm_bundle_schema.rb

## 本次不要做

- 不调用任何 Virtualization.framework 类型创建真实 VM 配置。
- 不创建真实 VM 磁盘内容，不分配用户目录下的 production bundle。
- 不实现资源准入、ISO 架构识别、安装状态判定或生命周期命令。
- 不新增用户可见未本地化字符串。
- 不实现多 VM UI、快照、共享目录、剪贴板、bridged networking、USB、音频、Rosetta 或 Intel 支持。

## PHASE_CONTRACT:FACT_AUDIT

- 检查命令：`ruby scripts/audit_vm_bundle_schema.rb`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`。
- 实际生产入口：AIVM root shell view model 使用 `VMBundleStore.defaultRootDirectory()` 加载元数据。
- 实际消费方：root app shell、future VM creation/lifecycle phases、AIVMTests。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| VM state and metadata types | AIVM model layer | store, root shell, tests | VM config is encoded or decoded | decode error surfaces to caller | model tests pass | phase-1-vm-model-persistence |
| Bundle layout constants | AIVM persistence layer | store and tests | Any VM path is resolved | invalid path is rejected | schema audit passes | phase-1-vm-model-persistence |
| Bundle store | AIVM persistence layer | root shell view model | App starts or tests operate on temp root | app shows empty state on load failure | create/load/delete tests pass | phase-1-vm-model-persistence |
| Root shell store hookup | AIVM app shell | SwiftUI root scene | App launches | no VM falls back to empty state | build/test passes | phase-1-vm-model-persistence |
| VM bundle schema audit | repository script | planctl required check | Phase completion runs checks | completion exits 2 | audit command exits 0 | phase-1-vm-model-persistence |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- required checks：`contract-lint`、`vm-bundle-schema-audit`、`macos-build-test`。
- Unit tests must create a temporary bundle root, save metadata, load it back, update it, list it, and delete only that bundle.
- Schema audit must confirm source contains schema version, five states, two boot sources, NAT mode and fixed bundle artifact names.

## PHASE_CONTRACT:FAILURE_MODES

- 冷启动 / 重启：empty or unreadable store returns an empty VM summary to the shell instead of crashing.
- timeout / late reply：audit or build/test timeout must block `complete`.
- 并发 / 重复请求：temporary test roots isolate repeated test runs.
- 关闭开关 / 空状态 / fallback：no persisted VM keeps the phase-0 empty state active.
- 删除安全：delete must derive the target path from VM ID under the configured root and reject unsafe bundle names.

## 交付检查

- `ruby scripts/planctl lint-contracts --phase phase-1-vm-model-persistence` 返回 0。
- `ruby scripts/audit_vm_bundle_schema.rb` 返回 0。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- `allowed_paths` 与“本次允许改动”逐项对齐。
- Production Wiring 表中每个 artifact 都能映射到 required evidence。

## 执行裁决规则

- 如果需要改动本执行包未列出的路径，先停止并调整合同与 manifest。
- 如果新增代码触碰 Virtualization.framework 配置、真实 VM 启动、真实磁盘分配或资源准入，视为越界。
- 如果 app shell 只能在测试中使用 store，而生产 root scene 没有真实读取入口，本 phase 不得完成。
- 如果 bundle 删除逻辑可能删除 configured root 之外的路径，本 phase 不得完成。
