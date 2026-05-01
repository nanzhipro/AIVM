# Phase-Contract Execution Handoff

本文件用于长流程执行时的压缩恢复。不要一次性重新加载全部 phase 文档；恢复时按本文档与 manifest 继续。

## 当前状态

- State file: `plan/state.yaml`
- Handoff file: `plan/handoff.md`
- Updated at: `2026-05-01T13:04:19Z`
- Completed phases: `phase-0-app-shell-i18n, phase-1-vm-model-persistence, phase-2-admission-policy, phase-3-vz-configuration`

## 最近完成

- `phase-1-vm-model-persistence` VM model and bundle persistence: Added VM metadata, bundle layout/store persistence, root shell loading, schema audit, and tests.
- next focus: Promote phase-2 host admission and resource policy contracts, then implement host/ISO/resource validation.
- `phase-2-admission-policy` Host admission and resource policy: Added host, ISO, and resource admission policy with root create gating, audit coverage, and tests.
- next focus: Promote phase-3 Virtualization configuration builder contracts, then implement validated VZ configuration construction without starting the VM.
- `phase-3-vz-configuration` Virtualization configuration builder: Added a production VZ configuration builder with persistent runtime artifacts, NAT device graph, view-model readiness wiring, audit coverage, and tests.
- next focus: Promote phase-4 lifecycle state contracts, then implement VM lifecycle orchestration on top of the validated configuration builder.

## 下一 Phase

- `phase-4-lifecycle-state` VM lifecycle and state machine
- plan: `plan/phases/phase-4-lifecycle-state.md`
- execution: `plan/execution/phase-4-lifecycle-state.md`
- status: `placeholder contracts need upgrade first (plan/phases/phase-4-lifecycle-state.md, plan/execution/phase-4-lifecycle-state.md)`

下一步读取顺序：
1. `plan/common.md`
2. `plan/phases/phase-4-lifecycle-state.md`
3. `plan/execution/phase-4-lifecycle-state.md`

## 压缩恢复顺序

1. `plan/manifest.yaml`
2. `plan/handoff.md`
3. `next.phase.required_context`

## 压缩控制规则

- 永远不要一次性加载所有 phase 文档。
- 只在当前 phase 读取 plan/common.md、当前 phase plan 和当前 phase execution。
- 每完成一个 phase 后更新 handoff，再进入下一 phase。

## 连续执行命令

- next: `ruby scripts/planctl advance --strict`
- complete: `ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue`
- handoff-repair (manual recovery only): `ruby scripts/planctl handoff --write`
