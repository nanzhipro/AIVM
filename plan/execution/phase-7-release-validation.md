# Phase 7 执行包

## PHASE_CONTRACT:FACT_AUDIT

本执行包落实 `phase-7-release-validation`：完成 release readiness 文档、README 链接、自动审计脚本和最终 required checks。当前 phase 是交接与验证层，不改 VM runtime 行为。

## Allowed Paths

- `plan/phases/phase-7-release-validation.md`
- `plan/execution/phase-7-release-validation.md`
- `AIVM.xcodeproj/**`
- `AIVM/**`
- `AIVMTests/**`
- `AIVMUITests/**`
- `README.md`
- `docs/**`
- `scripts/audit_release_readiness.rb`
- `scripts/audit_localizations.rb`

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `docs/release-readiness.md` | Human release operator | Release candidate review starts | README points reviewers to this file |
| `scripts/audit_release_readiness.rb` | Manifest required check | Phase 7 completion and future validation | Nonzero exit blocks readiness claims |
| README release section | Repository entrypoint | Reviewer opens project | Detailed handoff stays in docs |

## Implementation Steps

1. Create `docs/release-readiness.md` with support matrix, validation commands, automated evidence, known limitations, privacy notes, and human decision checklist.
2. Update README with a short release readiness link only.
3. Add `scripts/audit_release_readiness.rb` and make it executable.
4. Ensure audit checks critical production files, entitlements, docs content, README link, required scripts, i18n resources, and disallowed dependency markers.
5. Run required checks and complete only after they pass.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required commands:

```bash
ruby scripts/planctl lint-contracts --phase phase-7-release-validation
ruby scripts/audit_release_readiness.rb
ruby scripts/audit_localizations.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Expected runtime evidence:

- Release doc lists the same required validation commands.
- Release doc distinguishes automated evidence from human-only release decisions.
- Audit verifies release docs and source boundaries without relying on future phases.

## PHASE_CONTRACT:FAILURE_MODES

- Missing docs or README link: audit fails.
- Missing entitlement, required scripts, or locale resources: audit fails.
- Disallowed VM/dependency scope markers in production sources: audit fails.
- Build/test or localization regression: required checks fail.

## Done Checklist

- Formal contract lint passes.
- Release readiness doc is present and linked from README.
- Release readiness audit is executable and passes.
- Required checks in manifest pass.
