#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative_path)
  path = File.join(ROOT, relative_path)
  abort("[release-readiness-audit] missing #{relative_path}") unless File.file?(path)

  File.read(path)
end

def assert_include(content, token, label)
  abort("[release-readiness-audit] #{label} missing #{token}") unless content.include?(token)
end

readme = read('README.md')
doc = read('docs/release-readiness.md')
entitlements = read('AIVM/AIVM.entitlements')
project = read('project.yml')

assert_include(readme, '[docs/release-readiness.md](docs/release-readiness.md)', 'README')

required_doc_tokens = [
  'Apple silicon Mac',
  'macOS 14 or newer',
  'Ubuntu Desktop ARM64 LTS',
  'NAT only',
  '~/Library/Application Support/phas/VMs/<vm-id>.vmbundle/',
  'en',
  'zh-Hans',
  'ja',
  'ruby scripts/audit_release_readiness.rb',
  "xcodebuild -scheme AIVM -destination 'platform=macOS' build test",
  'does not prove a completed Ubuntu installation',
  'Human Decisions',
  'security, compliance, legal, or design review'
]

required_doc_tokens.each do |token|
  assert_include(doc, token, 'release readiness doc')
end

required_scripts = [
  'scripts/audit_localizations.rb',
  'scripts/audit_vm_bundle_schema.rb',
  'scripts/audit_admission_policy.rb',
  'scripts/audit_virtualization_config.rb',
  'scripts/audit_lifecycle_state.rb',
  'scripts/audit_diagnostics_privacy.rb',
  'scripts/audit_release_readiness.rb'
]

required_scripts.each do |relative_path|
  path = File.join(ROOT, relative_path)
  abort("[release-readiness-audit] missing #{relative_path}") unless File.file?(path)
  abort("[release-readiness-audit] #{relative_path} is not executable") unless File.executable?(path)
end

required_locale_files = %w[
  AIVM/Resources/en.lproj/Localizable.strings
  AIVM/Resources/zh-Hans.lproj/Localizable.strings
  AIVM/Resources/ja.lproj/Localizable.strings
]

required_locale_files.each do |relative_path|
  read(relative_path)
end

assert_include(entitlements, '<key>com.apple.security.virtualization</key>', 'entitlements')
assert_include(entitlements, '<true/>', 'entitlements')
abort('[release-readiness-audit] forbidden vm networking entitlement found') if entitlements.include?('com.apple.vm.networking')

assert_include(project, 'CODE_SIGN_ENTITLEMENTS: AIVM/AIVM.entitlements', 'project.yml')
assert_include(read('AIVM/VirtualMachineConsoleView.swift'), 'VZVirtualMachineView', 'console view')
assert_include(read('AIVM/VMDiagnosticsManager.swift'), 'diagnostics.json', 'diagnostics manager')

production_paths = Dir.glob(File.join(ROOT, 'AIVM/**/*.swift')).select { |path| File.file?(path) }
production_text = production_paths.map { |path| File.read(path) }.join("\n") + "\n" + project
forbidden_patterns = {
  /\bQEMU\b|\bUTM\b|Parallels|VMware/i => 'third-party virtualization dependency marker found',
  /com\.apple\.vm\.networking/ => 'forbidden networking entitlement marker found',
  /bridged\s+network/i => 'bridged networking marker found',
  /URLSession|NSURLConnection|https?:\/\// => 'remote client or endpoint marker found in production sources'
}

forbidden_patterns.each do |pattern, message|
  abort("[release-readiness-audit] #{message}") if production_text.match?(pattern)
end

puts '[release-readiness-audit] ok: release docs, boundaries, entitlements, and required artifacts found'