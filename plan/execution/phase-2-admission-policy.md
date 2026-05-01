# Phase 2 执行包

本文件不能单独使用。执行当前 phase 时，必须同时携带完整的 `plan/common.md` 和配对的 `plan/phases/phase-2-admission-policy.md`。

## 必带上下文

- plan/common.md
- plan/phases/phase-2-admission-policy.md
- plan/execution/phase-2-admission-policy.md

## 执行目标

- 落地 host / ISO / resource admission policy。
- 将 app shell 的创建入口接入 host-only gating。
- 用 XCTest 和 `scripts/audit_admission_policy.rb` 验证 blockers、warnings 和 allowed 决策。

## 本次允许改动

- plan/phases/phase-2-admission-policy.md
- plan/execution/phase-2-admission-policy.md
- AIVM.xcodeproj/**
- AIVM/**
- AIVMTests/**
- scripts/audit_admission_policy.rb

## 本次不要做

- 不创建、修改或删除真实 VM bundle。
- 不调用 Virtualization.framework 配置或 VM 启动 API。
- 不实现创建向导或用户可见错误展示。
- 不新增未本地化用户可见字符串。
- 不引入第三方 ISO 解析器、后台服务、下载器或网络依赖。

## PHASE_CONTRACT:FACT_AUDIT

- 检查命令：`ruby scripts/audit_admission_policy.rb`、`xcodebuild -scheme AIVM -destination 'platform=macOS' build test`。
- 实际生产入口：AIVM root shell view model evaluates host-only admission and exposes create enablement.
- 实际消费方：root app shell、future creation wizard、AIVMTests。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| artifact | producer | production caller | activation condition | fallback behavior | runtime evidence | owning phase |
| --- | --- | --- | --- | --- | --- | --- |
| Host environment model | admission layer | policy and view model | App checks host support | host blocker disables create | host tests pass | phase-2-admission-policy |
| Admission decision model | admission layer | policy callers | Any request is evaluated | blockers/warnings are explicit | policy tests pass | phase-2-admission-policy |
| ISO classification | admission layer | policy | ISO URL is selected | unknown distro warning only | ISO tests pass | phase-2-admission-policy |
| Resource thresholds | admission layer | policy | resources are configured | unsafe values block create | resource tests pass | phase-2-admission-policy |
| Root shell create gating | app shell | SwiftUI root scene | App launches | create entry disabled on unsupported host | build/test passes | phase-2-admission-policy |
| Admission audit script | repository script | planctl required check | Phase completion runs checks | completion exits 2 | audit exits 0 | phase-2-admission-policy |

## PHASE_CONTRACT:RUNTIME_EVIDENCE

- required checks：`contract-lint`、`admission-policy-audit`、`macos-build-test`。
- Unit tests cover supported host, unsupported host, macOS lower than 14, x86/AMD64 ISO mismatch, unknown distro warning, low CPU/memory/disk, and insufficient disk space.
- Root shell build proves production gating compiles in the app target.

## PHASE_CONTRACT:FAILURE_MODES

- 冷启动 / 重启：host-only evaluation must not require an ISO and must not throw.
- timeout / late reply：audit or build/test timeout blocks `complete`.
- 并发 / 重复请求：policy evaluation has no side effects and can run repeatedly.
- 关闭开关 / 空状态 / fallback：warnings allow continue; blockers prevent create.
- 安全边界：no real VM file creation, no Virtualization configuration, no guest startup.

## 交付检查

- `ruby scripts/planctl lint-contracts --phase phase-2-admission-policy` 返回 0。
- `ruby scripts/audit_admission_policy.rb` 返回 0。
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` 返回 0。
- `allowed_paths` 与“本次允许改动”逐项对齐。
- Production Wiring 表中每个 artifact 都能映射到 required evidence。

## 执行裁决规则

- 如果需要改动本执行包未列出的路径，先停止并调整合同与 manifest。
- 如果新增真实 VM 数据写入、Virtualization configuration 或启动逻辑，视为越界。
- 如果 policy 只能在测试中使用，root shell 没有生产接线，本 phase 不得完成。
- 如果硬性不支持条件只产生 warning 而不阻断，本 phase 不得完成。
