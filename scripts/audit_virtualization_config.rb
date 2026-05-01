#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative)
  File.read(File.join(ROOT, relative))
end

builder = read('AIVM/VMConfigurationBuilder.swift')
view_model = read('AIVM/VMHomeViewModel.swift')
tests = read('AIVMTests/VirtualizationConfigurationBuilderTests.swift')
entitlements = read('AIVM/AIVM.entitlements')

required_builder_tokens = [
  'import Virtualization',
  'VZVirtualMachineConfiguration',
  'VZGenericPlatformConfiguration',
  'VZEFIBootLoader',
  'VZEFIVariableStore',
  'VZGenericMachineIdentifier',
  'VZDiskImageStorageDeviceAttachment',
  'VZVirtioBlockDeviceConfiguration',
  'VZVirtioNetworkDeviceConfiguration',
  'VZNATNetworkDeviceAttachment',
  'VZVirtioGraphicsDeviceConfiguration',
  'VZVirtioGraphicsScanoutConfiguration',
  'VZUSBKeyboardConfiguration',
  'VZUSBScreenCoordinatePointingDeviceConfiguration',
  'VZVirtioEntropyDeviceConfiguration',
  'VZVirtioTraditionalMemoryBalloonDeviceConfiguration',
  'configuration.validate()',
  'store.layout.diskImageURL',
  'store.layout.machineIdentifierURL',
  'store.layout.nvramURL',
  'readOnly: true',
  'synchronizationMode: .fsync'
]

missing = required_builder_tokens.reject { |token| builder.include?(token) }

view_model_tokens = [
  'VMConfigurationBuilding',
  'configurationReadiness',
  'try configurationBuilder.build(for: metadata)',
  'configurationReadiness = .ready',
  'configurationReadiness = .failed'
]
missing.concat(view_model_tokens.reject { |token| view_model.include?(token) })

test_tokens = [
  'testInstallConfigurationCreatesValidatedDeviceGraphAndArtifacts',
  'testConfigurationValidateIsCalledWhenEntitlementIsAvailable',
  'testDiskBootOmitsInstallMediaAttachment',
  'testRepeatedBuildsReuseMachineIdentifier',
  'testMissingInstallMediaIsRejected',
  'testCorruptMachineIdentifierIsRejected',
  'testViewModelRecordsReadyConfigurationReadiness',
  'testViewModelRecordsFailedConfigurationReadiness'
]
missing.concat(test_tokens.reject { |token| tests.include?(token) })

if builder.include?('VZBridgedNetworkDeviceAttachment') || entitlements.include?('com.apple.vm.networking')
  missing << 'NAT-only networking without bridged entitlement'
end

if builder.include?('VZVirtualMachine(') || builder.include?('start(')
  missing << 'configuration-only builder without VM start'
end

if missing.any?
  warn "[virtualization-config-audit] missing or invalid: #{missing.join(', ')}"
  exit 1
end

puts '[virtualization-config-audit] ok: VZ configuration builder, artifacts, NAT wiring, and tests found'