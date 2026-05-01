# Phase 0 执行包

本文件不能单独使用。执行当前 phase 时，必须同时携带完整的 `plan/common.md` 和配对的 `plan/phases/phase-0-app-shell-i18n.md`。

## 必带上下文

- plan/common.md
- plan/phases/phase-0-app-shell-i18n.md
- plan/execution/phase-0-app-shell-i18n.md

## 执行目标

- 将当前仓库的 Phase-Contract 初始脚手架纳入首个里程碑，避免未跟踪规划制品阻断 allowed_paths gate。
- 落地可构建的 AIVM macOS app shell、entitlement、测试入口和三语言本地化资源。
- 通过脚本化审计保证 `zh-Hans`、`en`、`ja` 文案 key 一致、短句化且不含禁用过程语言。

## 本次允许改动

- PRD.md
- plan/**
- scripts/planctl
- .github/copilot-instructions.md
- CLAUDE.md
- AGENTS.md
- .gitignore
- project.yml
- plan/phases/phase-0-app-shell-i18n.md
- plan/execution/phase-0-app-shell-i18n.md
- AIVM.xcodeproj/**
- AIVM/**
- AIVMTests/**
- AIVMUITests/**
- scripts/audit_localizations.rb
- README.md

## 本次不要做

- 不创建 VM bundle、虚拟磁盘、NVRAM、machine identifier 或真实 VM 配置。
- 不启动 `VZVirtualMachine`，不嵌入 `VZVirtualMachineView`。
- 不实现完整创建向导、资源准入检查、生命周期状态机或日志导出。
- 不加入 bridged networking、共享目录、剪贴板、USB、音频、Rosetta 或 Intel Mac 支持。

## PHASE_CONTRACT:FACT_AUDIT

- 检查命令：`xcodebuild -list -project AIVM.xcodeproj`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`、`ruby scripts/audit_localizations.rb`。
- 实际生产入口：AIVM app target 的 `App` entry point 和 root SwiftUI scene。
- 实际消费方：macOS app launcher、root app shell、localization tests。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| `AIVM` app target | Xcode project | macOS app launcher | User opens AIVM.app | App cannot launch | `xcodebuild -list -project AIVM.xcodeproj` lists `AIVM` | phase-0-app-shell-i18n |
| Root app shell view | AIVM app entry | SwiftUI root scene | App launches | Empty state is absent | build test compiles app module | phase-0-app-shell-i18n |
| Virtualization entitlement file | AIVM target settings | Code signing at build time | App target is built | Later VM start fails entitlement checks | build settings or project file references entitlement | phase-0-app-shell-i18n |
| Three-language string resource | AIVM resource bundle | SwiftUI labels/buttons/errors | Locale is `zh-Hans`, `en`, or `ja` | English fallback for unsupported locale | localization audit passes | phase-0-app-shell-i18n |
| `scripts/audit_localizations.rb` | repository script | planctl required check | Phase completion runs required checks | completion exits 2 | `localization-audit` check passes | phase-0-app-shell-i18n |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- required checks：`contract-lint`、`xcode-project-list`、`localization-audit`、`macos-build-test`。
- optional checks：`ui-smoke`。
- 运行时证据：Xcode lists the scheme, macOS build/test exits 0, localization audit exits 0, optional UI smoke opens the app shell.

## PHASE_CONTRACT:FAILURE_MODES

- 冷启动 / 重启：missing app target, scheme, app entry, or entitlement file must fail required checks.
- timeout / late reply：build or UI smoke timeout must be reported by planctl and must not update `plan/state.yaml`.
- 并发 / 重复请求：re-running `ruby scripts/audit_localizations.rb` must not edit localization resources.
- 关闭开关 / 空状态 / fallback：unsupported locale fallback may use English; required locales must have explicit values.

## 交付检查

- `ruby scripts/planctl lint-contracts --phase phase-0-app-shell-i18n` 返回 0。
- `allowed_paths` 与“本次允许改动”逐项对齐。
- `xcodebuild -list -project AIVM.xcodeproj` 返回 0。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- `ruby scripts/audit_localizations.rb` 返回 0，并输出三语言 key 一致性结果。
- Production Wiring 表中每个 artifact 都能映射到 required 或 optional evidence。

## 执行裁决规则

- 如果需要改动本执行包未列出的路径，先停止并调整合同与 manifest。
- 如果某个用户可见字符串不能从本地化资源追踪到 `zh-Hans`、`en`、`ja` 三种值，本 phase 不得完成。
- 如果只能证明测试 target 存在，不能证明 app target 或 root scene 可构建，本 phase 不得完成。
- 如果新增 VM 运行逻辑、bundle 创建逻辑或 Virtualization 配置构建逻辑，视为越界。
