#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative)
  File.read(File.join(ROOT, relative))
end

lifecycle = read('AIVM/VMLifecycleController.swift')
view_model = read('AIVM/VMHomeViewModel.swift')
tests = read('AIVMTests/VMLifecycleControllerTests.swift')

required_lifecycle_tokens = [
  'import Virtualization',
  'import OSLog',
  'enum VMLifecycleError',
  'struct VMStateMachine',
  'case .draft, .stopped, .error',
  'case .installing, .running',
  'protocol VMLifecycleControlling',
  'protocol VirtualMachineOperating',
  'final class VZVirtualMachineAdapter',
  'VZVirtualMachine(configuration: configuration)',
  'try await virtualMachine.start()',
  'virtualMachine.stop',
  'final class VMLifecycleController',
  'configurationBuilder.build(for: metadata)',
  'activeMachine',
  'try store.save(updated)',
  'Logger(subsystem: "pro.nanzhi.AIVM", category: "VMLifecycle")'
]

missing = required_lifecycle_tokens.reject { |token| lifecycle.include?(token) }

view_model_tokens = [
  'lifecycleController: VMLifecycleControlling',
  'canStartVM',
  'canStopVM',
  'func startCurrentVM() async',
  'func stopCurrentVM() async',
  'try await lifecycleController.start(metadata: metadata)',
  'try await lifecycleController.stop(metadata: metadata)'
]
missing.concat(view_model_tokens.reject { |token| view_model.include?(token) })

test_tokens = [
  'testStateMachineStartAndStopPermissions',
  'testInstallMediaStartPersistsInstalling',
  'testDiskStartPersistsRunning',
  'testInvalidStartTransitionDoesNotMutateMetadata',
  'testBuilderFailurePersistsError',
  'testStartFailurePersistsError',
  'testStopPersistsStopped',
  'testStopFailurePersistsError',
  'testStopWithoutActiveMachineIsRejectedWithoutMutation',
  'testViewModelStartActionUsesLifecycleController',
  'testViewModelStopActionUsesLifecycleController',
  'FakeVirtualMachine'
]
missing.concat(test_tokens.reject { |token| tests.include?(token) })

if lifecycle.include?('VZVirtualMachineView') || view_model.include?('VZVirtualMachineView')
  missing << 'no VZVirtualMachineView in lifecycle phase'
end

if missing.any?
  warn "[lifecycle-state-audit] missing or invalid: #{missing.join(', ')}"
  exit 1
end

puts '[lifecycle-state-audit] ok: state machine, lifecycle controller, logging, and view-model actions found'