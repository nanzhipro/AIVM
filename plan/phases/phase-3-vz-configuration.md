# Phase 3: Virtualization configuration builder

## Phase Contract

本 phase 交付 AIVM 的 Virtualization.framework 配置构造层。它必须把已持久化的 VM metadata、bundle layout 和 phase-2 admission 结果转化为可验证的 `VZVirtualMachineConfiguration`，但不得启动 VM、展示 VM 画面或实现 lifecycle 操作。

## PHASE_CONTRACT:FACT_AUDIT

- AIVM MVP 只面向 Apple silicon macOS 14+，guest 只承诺 ARM64 Linux。
- 配置底座必须使用 Apple Virtualization.framework：`VZVirtualMachineConfiguration`、`VZGenericPlatformConfiguration`、`VZEFIBootLoader`、`VZVirtualMachine` 后续 lifecycle 接入前的配置必须先能独立 validate。
- VM bundle 的稳定路径来自 phase 1：`Disk.img`、`MachineIdentifier`、`NVRAM`、`config.json`、`logs/`。
- phase 2 已提供 host、ISO、resource admission；本 phase 不重复做产品 admission，只在构造 VZ 配置时拒绝缺失的 install media、非法 boot source、非 NAT 网络或无效 bundle artifact。
- MVP 网络必须是 NAT，不需要 `com.apple.vm.networking` entitlement。
- 本 phase 不实现多 VM、snapshot、shared folder、clipboard、USB passthrough、audio、Rosetta、auto ISO download、unattended install。

## PHASE_CONTRACT:PRODUCTION_WIRING

### Component Adoption Table

| Component | Production caller | Activation condition | Fallback |
| --- | --- | --- | --- |
| `VMConfigurationBuilder` | `VMHomeViewModel.reload()` through an injectable builder protocol | A persisted VM metadata exists and host-only admission allows VM creation | Publish configuration readiness as failed; do not crash or start a VM |
| Bundle runtime artifacts | `VMConfigurationBuilder.build(for:)` | A metadata-backed VM needs a validated VZ configuration | Create missing `Disk.img`, `MachineIdentifier`, and `NVRAM`; reject invalid persisted identifiers |
| VZ device graph | `VMConfigurationBuilder.build(for:)` | Build mode is install media or disk boot | Attach only disk for disk boot; attach disk plus read-only ISO for install media boot |

## Scope

Must implement:

- A production builder that returns a validated `VZVirtualMachineConfiguration` without starting a VM.
- Persistent machine identity and EFI variable store files under the VM bundle.
- Sparse raw disk image creation using the metadata resource size.
- Generic ARM Linux device graph: EFI boot loader, generic platform, virtio block storage, NAT virtio network, virtio graphics scanout, USB keyboard, USB pointing device, entropy device, and memory balloon.
- Install mode with read-only ISO attachment when `bootSource == .installMedia` and disk mode without ISO when `bootSource == .disk`.
- Unit tests proving validated configuration shape, persistent artifact reuse, disk boot behavior, missing ISO rejection, and VMHomeViewModel production wiring.
- `scripts/audit_virtualization_config.rb` to statically prove the expected framework classes and wiring exist.

Must not implement:

- `VZVirtualMachine` lifecycle start/stop/pause.
- `VZVirtualMachineView` UI embedding.
- Guest installation completion detection.
- UI create flow or user-visible error copy beyond existing localized keys.
- Bridged networking or additional entitlements.

## PHASE_CONTRACT:RUNTIME_EVIDENCE

Required evidence before completion:

- `ruby scripts/planctl lint-contracts --phase phase-3-vz-configuration` passes.
- `ruby scripts/audit_virtualization_config.rb` passes and verifies the required VZ classes, artifact persistence, NAT-only networking, and view model wiring.
- `xcodebuild -scheme AIVM -destination 'platform=macOS' build test` passes.
- XCTest must build at least one `VZVirtualMachineConfiguration`, assert the produced storage/network/input/graphics shape, and call `validate()`. In unsigned local test hosts where Virtualization.framework reports only the missing `com.apple.security.virtualization` entitlement, that specific validation probe may be skipped while production builder defaults to `validate()`.

## PHASE_CONTRACT:FAILURE_MODES

- If install metadata lacks an ISO path, the builder throws a typed missing-media error and the view model records failed readiness.
- If the persisted machine identifier is corrupt, the builder rejects it instead of silently replacing identity.
- If a bundle path or artifact cannot be created, the underlying file error is surfaced to the caller and no VM is started.
- If metadata requests a non-NAT network mode in the future, the builder rejects it rather than silently switching behavior.
- If `VZVirtualMachineConfiguration.validate()` fails for any reason other than the known unsigned test-host entitlement probe, completion is blocked until the configuration is corrected.

## Completion Criteria

- The builder is present in production code and reachable from the home view model.
- Configuration creation is deterministic from `VMMetadata` plus `VMBundleStore` layout.
- Runtime artifacts are persisted under the phase-1 bundle layout and reused across repeated builds.
- Required checks in `plan/manifest.yaml` pass.
