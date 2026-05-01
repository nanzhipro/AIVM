#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'set'

ROOT = File.expand_path('..', __dir__)
LOCALES = %w[en zh-Hans ja].freeze
RESOURCE_ROOT = File.join(ROOT, 'AIVM', 'Resources')
STRINGS_FILE = 'Localizable.strings'
MAX_COPY_LENGTH = 96
BANNED_PATTERNS = [
  /\bphase\b/i,
  /\bstep\b/i,
  /\bprocess\b/i,
  /执行阶段/,
  /流程进行中/,
  /过程/,
  /ステップ/,
  /処理中/,
  /プロセス/
].freeze

def fail_with(message)
  warn "[localization-audit] #{message}"
  exit 1
end

def parse_strings(path)
  fail_with("missing #{path}") unless File.file?(path)

  output, status = Open3.capture2e('/usr/bin/plutil', '-convert', 'json', '-o', '-', path)
  fail_with("invalid .strings file #{path}: #{output.strip}") unless status.success?

  JSON.parse(output)
rescue JSON::ParserError => error
  fail_with("invalid JSON from plutil for #{path}: #{error.message}")
end

localized = LOCALES.to_h do |locale|
  path = File.join(RESOURCE_ROOT, "#{locale}.lproj", STRINGS_FILE)
  [locale, parse_strings(path)]
end

reference_keys = localized.fetch('en').keys.to_set
fail_with('en localization has no keys') if reference_keys.empty?

localized.each do |locale, strings|
  keys = strings.keys.to_set
  missing = reference_keys - keys
  extra = keys - reference_keys

  fail_with("#{locale} missing keys: #{missing.to_a.sort.join(', ')}") unless missing.empty?
  fail_with("#{locale} extra keys: #{extra.to_a.sort.join(', ')}") unless extra.empty?

  strings.each do |key, value|
    fail_with("#{locale}.#{key} is empty") if value.to_s.strip.empty?
    fail_with("#{locale}.#{key} is too long") if value.length > MAX_COPY_LENGTH
    fail_with("#{locale}.#{key} contains a line break") if value.include?("\n") || value.include?("\r")

    BANNED_PATTERNS.each do |pattern|
      fail_with("#{locale}.#{key} contains banned wording: #{pattern.inspect}") if value.match?(pattern)
    end
  end
end

puts "[localization-audit] ok: #{LOCALES.join(', ')} share #{reference_keys.length} keys"
