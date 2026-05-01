#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)

def read(relative_path)
  path = File.join(ROOT, relative_path)
  abort("[diagnostics-privacy-audit] missing #{relative_path}") unless File.file?(path)

  File.read(path)
end

diagnostics = read('AIVM/VMDiagnosticsManager.swift')
view_model = read('AIVM/VMHomeViewModel.swift')
root_view = read('AIVM/RootView.swift')
tests = read('AIVMTests/VMHomeViewModelUITests.swift')

required_diagnostics_tokens = [
  'VMDiagnosticSnapshot',
  'VMDiagnosticsProviding',
  'VMDiagnosticsManager',
  'store.layout.logsURL',
  'diagnostics.json',
  'NSWorkspace',
  'installMediaName',
  'lastPathComponent'
]

required_diagnostics_tokens.each do |token|
  abort("[diagnostics-privacy-audit] missing diagnostics token: #{token}") unless diagnostics.include?(token)
end

required_view_model_tokens = [
  'replaceInstallMedia(from installMediaURL',
  'openDiagnostics()',
  'canReplaceInstallMedia',
  'diagnosticsProvider.openDiagnosticsDirectory'
]

required_view_model_tokens.each do |token|
  abort("[diagnostics-privacy-audit] missing view-model token: #{token}") unless view_model.include?(token)
end

required_root_tokens = [
  'viewModel.replaceInstallMedia',
  'viewModel.openDiagnostics()',
  'LocalizationKey.viewLogs.rawValue',
  'LocalizationKey.chooseAnotherISO.rawValue'
]

required_root_tokens.each do |token|
  abort("[diagnostics-privacy-audit] missing root UI token: #{token}") unless root_view.include?(token)
end

required_test_tokens = [
  'testDiagnosticsSnapshotIsLocalAndOmitsFullInstallMediaPath',
  'testInvalidReplacementISODoesNotMutateMetadata',
  'Phase6FakeDiagnosticsProvider'
]

required_test_tokens.each do |token|
  abort("[diagnostics-privacy-audit] missing test evidence: #{token}") unless tests.include?(token)
end

forbidden_diagnostics_patterns = {
  /var\s+installMediaPath/ => 'diagnostic snapshot must not expose full install media path',
  /URLSession|NSURLConnection/ => 'diagnostics must not use network clients',
  /https?:\/\// => 'diagnostics must not embed remote endpoints',
  /upload|telemetry|crash\s*report/i => 'diagnostics must not upload or report remotely',
  /screen\s*capture|keyboard|guest\s*file|packet\s*capture/i => 'diagnostics must not collect guest screen, input, files, or packets'
}

forbidden_diagnostics_patterns.each do |pattern, message|
  abort("[diagnostics-privacy-audit] #{message}") if diagnostics.match?(pattern)
end

unless diagnostics.include?('fileManager.createDirectory(at: logsURL')
  abort('[diagnostics-privacy-audit] diagnostics directory is not created under logsURL')
end

puts '[diagnostics-privacy-audit] ok: local diagnostics, ISO recovery, and privacy checks found'