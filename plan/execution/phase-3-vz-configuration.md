# Phase 3 执行包

## PHASE_CONTRACT:FACT_AUDIT

本执行包落实 `phase-3-vz-configuration`：把 metadata、bundle layout 和 Virtualization.framework 连接起来，形成可 validate 的 VM 配置。当前 phase 只允许构造配置和准备本地 artifact，不允许启动 VM 或展示 VM console。

## Allowed Paths

- `plan/phases/phase-3-vz-configuration.md`
- `plan/execution/phase-3-vz-configuration.md`
- `AIVM.xcodeproj/**`
- `AIVM/**`
- `AIVMTests/**`
- `scripts/audit_virtualization_config.rb`

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMConfigurationBuilder` | `VMHomeViewModel.reload()` | `store.loadCurrent()` returns metadata and host-only admission is allowed | Readiness becomes failed; app remains usable |
| `VMConfigurationBuilding` protocol | `VMHomeViewModel` initializer | Production uses the real builder; tests can inject a failing/succeeding builder | Dependency failures stay local to readiness |
| VZ configuration artifact preparation | `VMConfigurationBuilder.build(for:)` | Build requested for persisted metadata | Missing artifacts are created; corrupt identifiers throw typed errors |

## Implementation Steps

1. Add `VMConfigurationBuilder` and a small injectable protocol/result model in `AIVM/`.
2. Implement artifact preparation for `Disk.img`, `MachineIdentifier`, and `NVRAM` using `VMBundleStore.layout`.
3. Build and validate a `VZVirtualMachineConfiguration` with generic platform, EFI boot, virtio storage, NAT networking, graphics, keyboard, pointer, entropy, and memory balloon.
4. Wire `VMHomeViewModel.reload()` to prepare configuration readiness for persisted metadata without starting a VM.
5. Add `AIVMTests/VirtualizationConfigurationBuilderTests.swift` covering install config, disk boot config, artifact reuse, missing ISO failure, corrupt identifier failure, and view model wiring.
6. Add `scripts/audit_virtualization_config.rb` for static policy checks.
7. Run required checks and complete the phase only after they pass.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required commands:

```bash
ruby scripts/planctl lint-contracts --phase phase-3-vz-configuration
ruby scripts/audit_virtualization_config.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Expected runtime evidence:

- XCTest creates a temporary bundle, writes a minimal valid ARM64 Ubuntu ISO fixture, and builds a VZ configuration with the expected device graph.
- XCTest explicitly calls `validate()` and either succeeds or skips only the known unsigned test-host entitlement limitation.
- XCTest confirms disk boot does not attach install media.
- XCTest confirms repeated builds reuse the persisted machine identifier.
- XCTest confirms VMHomeViewModel records ready/failed configuration readiness through injected builders.

## PHASE_CONTRACT:FAILURE_MODES

- Missing ISO path or missing ISO file must throw typed builder errors.
- Corrupt `MachineIdentifier` data must throw a typed builder error.
- Any file-system failure while creating disk/NVRAM/artifacts must propagate and prevent readiness from being marked ready.
- Any VZ validation failure other than the known unsigned test-host entitlement probe must fail tests and block `complete`.
- Generated build products such as `DerivedData/` must remain ignored.

## Done Checklist

- Formal contract lint passes.
- Builder is called from production code, not only tests.
- Required VZ classes are present in source and audited.
- Unit tests verify validated configuration and failure modes.
- Manifest required checks pass.
