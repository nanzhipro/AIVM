# Phase 7: Release validation and operator handoff

## Phase Contract

本 phase 交付最终发布验证与人工交接材料：把 AIVM MVP 的支持范围、验证命令、已知限制、隐私边界、发布前人工检查和回归证据沉淀到内部文档，并用脚本审计 release readiness。当前 phase 不新增业务功能，不扩大 MVP 范围。

## PHASE_CONTRACT:FACT_AUDIT

- Release readiness 必须覆盖 Apple silicon、macOS 14+、一台 ARM64 Linux VM、Ubuntu Desktop ARM64 LTS、NAT、本地 bundle 和三语言文案。
- Operator handoff 必须明确哪些动作由人类决定：上线、打 tag、创建 release、归档 plan、安全/合规/法务复核。
- README 只保留概括与链接；详细验收矩阵、运行命令、已知限制和交接事项必须放在 `docs/`。
- 发布验证不得声称已完成真实 Ubuntu 安装或真实 guest 启动；当前自动化只证明配置、状态、UI、诊断和本地持久化链路。
- Release audit 必须检查 README 链接、release 文档、关键 audit scripts、entitlement、三语言本地化和禁止的非目标依赖。
- 本 phase 不得新增远端服务、VM 功能或 UI 主路径行为。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `docs/release-readiness.md` | Human operator and release reviewers | Final release validation begins | README links to the document for detailed handoff |
| `scripts/audit_release_readiness.rb` | Manifest required check | Phase 7 and future releases run checks | Fails if release evidence or boundaries drift |
| README release link | Repository entrypoint | Developer or reviewer opens project | Detailed material remains in docs, keeping README concise |

## Scope

Must implement:

- A release readiness / operator handoff document under `docs/`.
- A concise README link to the release readiness document.
- `scripts/audit_release_readiness.rb` checking docs, README linkage, release commands, critical files, entitlement, i18n resources, and disallowed dependency markers.
- Final required checks: release readiness audit, localization audit, and full macOS build/test.

Must not implement:

- New VM features, UI flows, networking modes, guest integration, installer automation, release tag creation, publishing, notarization, or archive moves.
- Claims that automated tests booted and installed a real Ubuntu guest.
- Manual edits to `plan/state.yaml` / `plan/handoff.md` outside `planctl complete` / `finalize`.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required evidence before completion:

- `ruby scripts/planctl lint-contracts --phase phase-7-release-validation` passes.
- `ruby scripts/audit_release_readiness.rb` passes.
- `ruby scripts/audit_localizations.rb` passes.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` passes.
- `git status --short --ignored` shows only intended source/doc changes plus ignored build artifacts before completion.

## PHASE_CONTRACT:FAILURE_MODES

- Missing release doc or README link blocks completion.
- Release doc overclaims real guest installation/boot validation blocks completion.
- Disallowed dependency markers such as QEMU, UTM, Parallels, VMware, telemetry upload, or bridged networking block completion when found in production sources.
- Required checks fail if localization or build/test regress.

## Completion Criteria

- Release readiness doc and audit script are present, linked, executable, and passing.
- README remains concise and points to detailed release handoff.
- Required checks in `plan/manifest.yaml` pass.
