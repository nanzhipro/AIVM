#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative_path)
  File.read(File.join(ROOT, relative_path))
end

def assert_contains(label, content, needle)
  return if content.include?(needle)

  warn "[admission-policy-audit] missing #{label}: #{needle}"
  exit 1
end

policy = read('AIVM/AdmissionPolicy.swift')
view_model = read('AIVM/VMHomeViewModel.swift')
root_view = read('AIVM/RootView.swift')

{
  'minimum CPU' => 'static let minimumCPUCount = 2',
  'minimum memory' => 'static let minimumMemoryBytes: UInt64 = 4 * 1024 * 1024 * 1024',
  'minimum disk' => 'static let minimumDiskBytes: UInt64 = 32 * 1024 * 1024 * 1024',
  'disk buffer' => 'static let diskSafetyBufferBytes: UInt64 = 8 * 1024 * 1024 * 1024',
  'minimum macOS' => 'static let minimumMacOSMajorVersion = 14',
  'ARM64 host' => 'host.architecture != "arm64"',
  'host-only evaluation' => 'func evaluateHost(_ host: HostEnvironment) -> AdmissionDecision',
  'request evaluation' => 'func evaluate(request: VMCreationRequest, host: HostEnvironment) -> AdmissionDecision',
  'ARM64 ISO classifier' => 'name.contains("arm64") || name.contains("aarch64")',
  'x86 ISO classifier' => 'name.contains("amd64") || name.contains("x86_64") || name.contains("x64")',
  'Ubuntu support' => 'return .primaryUbuntuARM64',
  'Fedora support' => 'return .supplementalFedoraARM64'
}.each do |label, needle|
  assert_contains(label, policy, needle)
end

%w[
  unsupportedHostArchitecture
  unsupportedMacOSVersion
  missingISO
  unreadableISO
  invalidISOExtension
  isoArchitectureMismatch
  unknownDistribution
  cpuTooLow
  cpuTooHigh
  memoryTooLow
  memoryTooHigh
  diskTooLow
  insufficientDiskSpace
].each do |code|
  assert_contains("issue code #{code}", policy, "case #{code}")
end

assert_contains('view model admission state', view_model, '@Published private(set) var hostAdmission: AdmissionDecision')
assert_contains('view model host provider', view_model, 'hostEnvironmentProvider: @escaping () -> HostEnvironment = { HostEnvironment.current() }')
assert_contains('root create gating', root_view, '.disabled(!viewModel.canCreateVMOnHost)')

puts '[admission-policy-audit] ok: host, ISO, resource policy, and root gating found'