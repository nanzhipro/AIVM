# Phase 0: Native app shell and i18n copy foundation

## 阶段定位

建立可构建的原生 macOS 应用壳、Virtualization entitlement 和三语言本地化文案基线，为后续 VM 能力提供真实生产入口。

## 必带上下文

- plan/common.md
- plan/phases/phase-0-app-shell-i18n.md
- plan/execution/phase-0-app-shell-i18n.md

## 阶段目标

- 将 PRD 与 Phase-Contract 初始脚手架纳入首个可审计里程碑。
- 创建 AIVM macOS 应用 target、测试 target 和可被 `xcodebuild` 发现的 scheme。
- 接入 `com.apple.security.virtualization` entitlement，并保留后续 Virtualization.framework 调用所需的应用入口。
- 建立 `zh-Hans`、`en`、`ja` 三语言本地化资源，覆盖首页空状态、创建入口、状态标签和关键错误恢复动作的首批文案。
- 提供本地化审计脚本，检查三语言 key 集合一致、空值缺失和禁用过程语言。

## 实施范围

- Xcode project、macOS app target、测试 target、entitlements、应用入口、根视图和构建产物忽略规则。
- 本地化资源、首批用户可见文案和本地化审计脚本。
- README 的项目概览与本地开发入口。

## 本阶段产出

- 可构建的 AIVM macOS 应用项目。
- 三语言本地化资源与审计脚本。
- 覆盖 app shell 和本地化资源的 XCTest 或脚本化检查。

## 明确不做

- 不创建真实 VM bundle、磁盘、NVRAM 或 machine identifier。
- 不构建 `VZVirtualMachineConfiguration` 或启动 `VZVirtualMachine`。
- 不实现创建向导完整表单、VM 详情页、运行窗口、错误诊断导出。
- 不引入自动下载镜像、多 VM 管理或非 NAT 网络能力。

## PHASE_CONTRACT:FACT_AUDIT

- 真实入口：AIVM macOS app target 的 `App` 入口和 root SwiftUI view。
- 真实调用方：macOS 启动应用后加载 root scene；测试 target 通过 app module 读取本地化资源。
- target / 打包归属：`AIVM` macOS app target、`AIVMTests`、`AIVMUITests`。
- 证据命令：`xcodebuild -list -project AIVM.xcodeproj`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`、`ruby scripts/audit_localizations.rb`。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| `AIVM` macOS app target | Xcode project | macOS app launcher | User opens AIVM.app | Launch fails with build/runtime error | `xcodebuild -list -project AIVM.xcodeproj` lists the scheme | phase-0-app-shell-i18n |
| `com.apple.security.virtualization` entitlement | AIVM entitlements file | AIVM app target signing settings | App target is built | Virtualization APIs fail entitlement checks later | build settings include the entitlement file | phase-0-app-shell-i18n |
| Root app shell view | AIVM app entry | SwiftUI scene hierarchy | App launches | Empty state is unavailable | UI smoke target can open the app shell | phase-0-app-shell-i18n |
| `Localizable.xcstrings` or equivalent resource | App resources | Root app shell and tests | Locale is `zh-Hans`, `en`, or `ja` | English fallback only for OS-level unsupported locale | `ruby scripts/audit_localizations.rb` passes | phase-0-app-shell-i18n |
| localization audit script | repository scripts | `complete` required check | Phase completion runs required checks | Phase completion is blocked | `localization-audit` required check passes | phase-0-app-shell-i18n |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- `xcodebuild -list -project AIVM.xcodeproj` proves the project and scheme are visible to Xcode.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` proves the app shell and tests compile under the macOS destination.
- `ruby scripts/audit_localizations.rb` proves `zh-Hans`、`en`、`ja` keys match and banned process-language tokens are absent from user-visible strings.
- Optional UI smoke proves the app shell can launch far enough to render the localized empty state.

## PHASE_CONTRACT:FAILURE_MODES

- 启动 / 冷启动：missing scheme、missing app entry、missing entitlement file must fail a required check.
- 重启 / 恢复：re-running tests after a clean build must read the same localization resources from source control.
- 超时 / late reply：Xcode build timeout must stop completion and leave `plan/state.yaml` unchanged.
- 并发 / 重复触发：running localization audit more than once must produce the same pass/fail result without modifying files.
- 配置关闭 / 空状态 / fallback：unsupported OS locale may fall back to English, while `zh-Hans`、`en`、`ja` must resolve explicit strings.

## 完成判定

- `ruby scripts/planctl lint-contracts --phase phase-0-app-shell-i18n` 返回 0。
- `xcodebuild -list -project AIVM.xcodeproj` 返回 0，并输出 `AIVM` scheme。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- `ruby scripts/audit_localizations.rb` 返回 0，并检查 `zh-Hans`、`en`、`ja` key 集合一致。
- app target 的签名配置引用包含 `com.apple.security.virtualization` 的 entitlement 文件。

## 依赖关系

- 无前置 phase。
