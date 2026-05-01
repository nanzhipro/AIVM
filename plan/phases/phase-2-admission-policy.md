# Phase 2: Host admission and resource policy

## 阶段定位

建立创建前准入策略，确保不支持的宿主机、明显无效或架构不匹配的 ISO、以及越界资源配置在真正落盘或启动前被拦截；同时保留非主验收发行版的软警告路径。

## 必带上下文

- plan/common.md
- plan/phases/phase-2-admission-policy.md
- plan/execution/phase-2-admission-policy.md

## 阶段目标

- 定义可测试的 `HostEnvironment`、`VMCreationRequest`、`AdmissionIssue` 和 `AdmissionDecision`。
- 校验 Apple silicon / ARM64、macOS 14+、ISO 存在与可读、ISO 文件扩展名、文件名架构信号、资源下限和安全上限。
- 对 Ubuntu Desktop ARM64 / Fedora Workstation ARM64 之外的 ISO 给出 soft warning，但不阻断创建。
- 将 root app shell 的创建入口接入 host-only admission，当前宿主机不满足 MVP 边界时禁用创建入口。
- 提供 admission policy 审计脚本和 XCTest，证明 hard blocker / warning / allowed 决策稳定。

## 实施范围

- AIVM app module 内的 host environment、ISO classification、resource policy 和 admission decision types。
- Root shell view model 的 host-only admission hookup。
- AIVMTests 内的准入策略单元测试。
- Xcode project 更新和 `scripts/audit_admission_policy.rb`。

## 本阶段产出

- 可纯函数测试的 admission policy。
- 创建入口的真实 host-only gating。
- 覆盖 host、ISO、resource 三类准入规则的 XCTest。
- schema/规则审计脚本。

## 明确不做

- 不创建 VM bundle、磁盘、NVRAM 或 machine identifier。
- 不执行完整 ISO 内容解析、mount、校验和、自动下载或发行版在线识别。
- 不构建 Virtualization configuration，不启动 VM。
- 不实现创建向导 UI、错误弹窗或诊断导出。
- 不支持 Intel Mac、x86_64 guest、bridged networking 或自定义资源高级选项。

## PHASE_CONTRACT:FACT_AUDIT

- 真实入口：root shell view model 在 app 启动时运行 host-only admission，并把结果用于创建按钮 enabled state。
- 真实调用方：SwiftUI root scene、future creation wizard、AIVMTests、admission audit script。
- target / 打包归属：`AIVM` macOS app target、`AIVMTests`、repository scripts。
- 证据命令：`ruby scripts/audit_admission_policy.rb`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| `HostEnvironment` | admission layer | admission policy and view model | App evaluates host support | unsupported host blocks create entry | host policy tests pass | phase-2-admission-policy |
| `AdmissionPolicy` | admission layer | root shell view model and tests | App launches or creation request is evaluated | blocker prevents create, warning allows continue | admission tests and audit pass | phase-2-admission-policy |
| ISO classifier | admission layer | admission policy | User-selected ISO is evaluated | unknown distro becomes warning, wrong arch blocks | ISO tests pass | phase-2-admission-policy |
| resource policy | admission layer | admission policy | CPU/memory/disk values are evaluated | invalid config blocks create | resource tests pass | phase-2-admission-policy |
| root create button gating | AIVM app shell | SwiftUI root scene | App launches | create button remains disabled on unsupported host | build/test passes | phase-2-admission-policy |
| `scripts/audit_admission_policy.rb` | repository script | planctl required check | Phase completion runs required checks | completion exits 2 | admission-policy-audit passes | phase-2-admission-policy |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- `ruby scripts/audit_admission_policy.rb` proves required issue codes and thresholds are present in source.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` proves policy, root gating and tests compile and pass.
- Unit tests cover supported host allow, unsupported host block, x86 ISO mismatch, unknown distro warning, low resource blockers and disk space blocker.

## PHASE_CONTRACT:FAILURE_MODES

- 冷启动 / 重启：host-only admission must be deterministic and must not touch the file system beyond reading host properties.
- 超时 / late reply：audit/build timeout blocks completion and leaves state unchanged.
- 并发 / 重复触发：policy evaluation is side-effect free and safe to call repeatedly.
- 配置关闭 / 空状态 / fallback：unknown ISO compatibility is warning-only; hard support failures are blockers.
- 资源安全：unsafe CPU/memory/disk choices are blocked before bundle creation or VM startup.

## 完成判定

- `ruby scripts/planctl lint-contracts --phase phase-2-admission-policy` 返回 0。
- `ruby scripts/audit_admission_policy.rb` 返回 0。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- Tests 证明 hard blockers 阻止创建、soft warnings 不阻止、host-only admission 接入 root shell。
- 本 phase 未创建真实 VM 数据或引入 Virtualization configuration。

## 依赖关系

- depends_on: phase-1-vm-model-persistence
