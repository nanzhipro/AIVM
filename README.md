# AIVM

AIVM is a native macOS app for creating and running one local ARM64 Linux VM with Apple Virtualization.framework.

The MVP follows the product boundary in [PRD.md](PRD.md): Apple silicon, macOS 14+, Ubuntu Desktop ARM64 LTS as the primary validation target, persistent local VM storage, NAT networking, and concise zh-Hans/en/ja product copy.

## Development

```bash
xcodegen generate
ruby scripts/audit_localizations.rb
xcodebuild -scheme AIVM -destination 'platform=macOS' build test
```

Long-running implementation is governed by [plan/manifest.yaml](plan/manifest.yaml) and [plan/workflow.md](plan/workflow.md).