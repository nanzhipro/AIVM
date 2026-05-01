#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative_path)
  File.read(File.join(ROOT, relative_path))
end

def assert_contains(label, content, needle)
  return if content.include?(needle)

  warn "[vm-bundle-schema-audit] missing #{label}: #{needle}"
  exit 1
end

metadata = read('AIVM/VMMetadata.swift')
store = read('AIVM/VMBundleStore.swift')
view_model = read('AIVM/VMHomeViewModel.swift')
root_view = read('AIVM/RootView.swift')

assert_contains('schema version', metadata, 'static let currentSchemaVersion = 1')

{
  'Draft state' => 'case draft = "Draft"',
  'Installing state' => 'case installing = "Installing"',
  'Stopped state' => 'case stopped = "Stopped"',
  'Running state' => 'case running = "Running"',
  'Error state' => 'case error = "Error"',
  'install media boot source' => 'case installMedia = "InstallMedia"',
  'disk boot source' => 'case disk = "Disk"',
  'NAT network mode' => 'case nat = "NAT"'
}.each do |label, needle|
  assert_contains(label, metadata, needle)
end

{
  'bundle extension' => 'static let bundleExtension = "vmbundle"',
  'disk image name' => 'static let diskImageFileName = "Disk.img"',
  'machine identifier name' => 'static let machineIdentifierFileName = "MachineIdentifier"',
  'NVRAM name' => 'static let nvramFileName = "NVRAM"',
  'config name' => 'static let configFileName = "config.json"',
  'logs directory name' => 'static let logsDirectoryName = "logs"',
  'application support product path' => '.appendingPathComponent("phas", isDirectory: true)',
  'VMs root path' => '.appendingPathComponent("VMs", isDirectory: true)',
  'safe path containment' => 'func contains(_ url: URL) -> Bool'
}.each do |label, needle|
  assert_contains(label, store, needle)
end

assert_contains('production store hookup', view_model, 'init(store: VMBundleStore = VMBundleStore())')
assert_contains('root shell view model', root_view, '@StateObject private var viewModel = VMHomeViewModel()')

puts '[vm-bundle-schema-audit] ok: schema, states, bundle layout, and production hookup found'