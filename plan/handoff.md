# Phase-Contract Execution Handoff

本文件用于长流程执行时的压缩恢复。不要一次性重新加载全部 phase 文档；恢复时按本文档与 manifest 继续。

## 当前状态

- State file: `plan/state.yaml`
- Handoff file: `plan/handoff.md`
- Updated at: `2026-05-01T13:46:00Z`
- Finalized at: `2026-05-01T13:46:00Z`
- Completed phases: `phase-0-app-shell-i18n, phase-1-vm-model-persistence, phase-2-admission-policy, phase-3-vz-configuration, phase-4-lifecycle-state, phase-5-vm-ui, phase-6-errors-diagnostics, phase-7-release-validation`

## 最近完成

- `phase-5-vm-ui` Create, detail, and VM run UI: Added create/detail/run UI with ISO selection, localized VM details, start/stop/delete controls, VZ console wrapper, and view-model tests.
- next focus: Promote phase-6 diagnostics contracts, then add local recovery and diagnostics surfaces without expanding VM scope.
- `phase-6-errors-diagnostics` Error recovery and local diagnostics: Added local diagnostics snapshots, log-directory opening, ISO recovery, recovery UI actions, privacy audit, and tests.
- next focus: Promote phase-7 release validation contracts, then document release readiness and final operator handoff.
- `phase-7-release-validation` Release validation and operator handoff: Added release readiness documentation, README handoff link, release readiness audit, and final validation evidence.
- next focus: Run finalization, inspect the final ledger, and return release decisions to the human operator.

## 下一 Phase

- none

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
