# Phase-Contract Execution Handoff

本文件用于长流程执行时的压缩恢复。不要一次性重新加载全部 phase 文档；恢复时按本文档与 manifest 继续。

## 当前状态

- State file: `plan/state.yaml`
- Handoff file: `plan/handoff.md`
- Updated at: `2026-05-01T13:36:03Z`
- Completed phases: `phase-0-app-shell-i18n, phase-1-vm-model-persistence, phase-2-admission-policy, phase-3-vz-configuration, phase-4-lifecycle-state, phase-5-vm-ui, phase-6-errors-diagnostics`

## 最近完成

- `phase-4-lifecycle-state` VM lifecycle and state machine: Added VM lifecycle state machine, Virtualization-backed lifecycle controller, view-model start/stop actions, audit coverage, and fake-VM tests.
- next focus: Promote phase-5 create/detail/run UI contracts, then wire user-facing controls to lifecycle and persistence surfaces.
- `phase-5-vm-ui` Create, detail, and VM run UI: Added create/detail/run UI with ISO selection, localized VM details, start/stop/delete controls, VZ console wrapper, and view-model tests.
- next focus: Promote phase-6 diagnostics contracts, then add local recovery and diagnostics surfaces without expanding VM scope.
- `phase-6-errors-diagnostics` Error recovery and local diagnostics: Added local diagnostics snapshots, log-directory opening, ISO recovery, recovery UI actions, privacy audit, and tests.
- next focus: Promote phase-7 release validation contracts, then document release readiness and final operator handoff.

## 下一 Phase

- `phase-7-release-validation` Release validation and operator handoff
- plan: `plan/phases/phase-7-release-validation.md`
- execution: `plan/execution/phase-7-release-validation.md`
- status: `placeholder contracts need upgrade first (plan/phases/phase-7-release-validation.md, plan/execution/phase-7-release-validation.md)`

下一步读取顺序：
1. `plan/common.md`
2. `plan/phases/phase-7-release-validation.md`
3. `plan/execution/phase-7-release-validation.md`

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
