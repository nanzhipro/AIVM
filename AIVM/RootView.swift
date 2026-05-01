import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
  @StateObject private var viewModel = VMHomeViewModel()
  @State private var isISOImporterPresented = false
  @State private var isDeleteConfirmationPresented = false

  private let statusKeys: [LocalizationKey] = [
    .notInstalled,
    .installing,
    .stopped,
    .running,
    .needsAttention,
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
    }
    .frame(minWidth: 720, minHeight: 460)
    .background(Color(nsColor: .windowBackgroundColor))
    .fileImporter(
      isPresented: $isISOImporterPresented,
      allowedContentTypes: [UTType(filenameExtension: "iso") ?? .data],
      allowsMultipleSelection: false,
      onCompletion: handleISOSelection
    )
    .alert(localized(.deleteConfirmationTitle), isPresented: $isDeleteConfirmationPresented) {
      Button(localized(.cancel), role: .cancel) {}
      Button(localized(.deleteVM), role: .destructive) {
        viewModel.deleteCurrentVM()
      }
    } message: {
      Text(localized(.deleteConfirmationMessage))
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "terminal.fill")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(localized(.appTitle))
          .font(.title3.weight(.semibold))
          .accessibilityIdentifier(LocalizationKey.appTitle.rawValue)
        Text(localized(.supportedGuest))
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(LocalizationKey.supportedGuest.rawValue)
      }

      Spacer()

      Button {
        isISOImporterPresented = true
      } label: {
        Label(localized(.createVM), systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .disabled(!viewModel.canCreateVM)
      .accessibilityIdentifier(LocalizationKey.createVM.rawValue)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
  }

  @ViewBuilder
  private var content: some View {
    if let metadata = viewModel.metadata {
      vmSummary(metadata)
    } else {
      emptyState
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top, spacing: 18) {
        Image(systemName: "desktopcomputer")
          .font(.system(size: 42, weight: .regular))
          .foregroundStyle(.secondary)
          .frame(width: 56, height: 56)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 8) {
          Text(localized(.emptyTitle))
            .font(.title2.weight(.semibold))
            .accessibilityIdentifier(LocalizationKey.emptyTitle.rawValue)
          Text(localized(.emptySubtitle))
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(LocalizationKey.emptySubtitle.rawValue)
        }
      }

      if !viewModel.hostAdmission.isAllowed {
        issueBanner(for: viewModel.hostAdmission)
      } else if !viewModel.creationAdmission.isAllowed {
        issueBanner(for: viewModel.creationAdmission)
      }

      HStack(spacing: 10) {
        Button {
          isISOImporterPresented = true
        } label: {
          Label(localized(.selectISO), systemImage: "opticaldiscdrive")
        }
        .disabled(!viewModel.canCreateVMOnHost)
        .accessibilityIdentifier(LocalizationKey.selectISO.rawValue)
      }

      VStack(alignment: .leading, spacing: 10) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8
        ) {
          ForEach(statusKeys, id: \.rawValue) { key in
            Text(localized(key))
              .font(.caption.weight(.medium))
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(
                Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
              )
              .accessibilityIdentifier(key.rawValue)
          }
        }
      }

      Spacer()
    }
    .padding(32)
  }

  private func vmSummary(_ metadata: VMMetadata) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 18) {
        vmIcon

        VStack(alignment: .leading, spacing: 8) {
          Text(metadata.displayName)
            .font(.title2.weight(.semibold))
          Text(localized(metadata.state.localizedKey))
            .font(.body)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(metadata.state.localizedKey.rawValue)
        }

        Spacer()

        actionBar
      }

      if metadata.state == .error {
        noticeBanner(title: .startFailed, action: .retryStart)
      } else if viewModel.configurationReadiness == .failed {
        noticeBanner(title: .configInvalid, action: .chooseAnotherISO)
      }

      if !viewModel.creationAdmission.isAllowed {
        issueBanner(for: viewModel.creationAdmission)
      }

      Divider()

      HStack(alignment: .top, spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          Text(localized(.details))
            .font(.headline)
          detailRow(.cpu, value: "\(metadata.resources.cpuCount)")
          detailRow(.memory, value: formattedBytes(metadata.resources.memoryBytes))
          detailRow(.disk, value: formattedBytes(metadata.resources.diskBytes))
          detailRow(.installMedia, value: installMediaName(for: metadata))
          detailRow(.network, value: localizedValue(.networkNAT))
          detailRow(.bootSource, value: localizedValue(bootSourceKey(for: metadata.bootSource)))
        }
        .frame(width: 240, alignment: .leading)

        VStack(alignment: .leading, spacing: 12) {
          Text(localized(.console))
            .font(.headline)

          ZStack {
            if viewModel.displayVirtualMachine != nil {
              VirtualMachineConsoleView(virtualMachine: viewModel.displayVirtualMachine)
            } else {
              consolePlaceholder
            }
          }
          .frame(maxWidth: .infinity, minHeight: 260)
          .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer()
    }
    .padding(32)
  }

  private var actionBar: some View {
    HStack(spacing: 10) {
      Button {
        isISOImporterPresented = true
      } label: {
        Label(localized(.chooseAnotherISO), systemImage: "opticaldiscdrive")
      }
      .disabled(!viewModel.canReplaceInstallMedia)
      .accessibilityIdentifier(LocalizationKey.chooseAnotherISO.rawValue)

      Button {
        Task { await viewModel.startCurrentVM() }
      } label: {
        Label(localized(startActionKey), systemImage: "play.fill")
      }
      .disabled(!viewModel.canStartVM)
      .accessibilityIdentifier(LocalizationKey.startVM.rawValue)

      Button {
        Task { await viewModel.stopCurrentVM() }
      } label: {
        Label(localized(.stopVM), systemImage: "stop.fill")
      }
      .disabled(!viewModel.canStopVM)
      .accessibilityIdentifier(LocalizationKey.stopVM.rawValue)

      Button {
        viewModel.openDiagnostics()
      } label: {
        Label(localized(.viewLogs), systemImage: "doc.text.magnifyingglass")
      }
      .disabled(!viewModel.canOpenDiagnostics)
      .accessibilityIdentifier(LocalizationKey.viewLogs.rawValue)

      Button(role: .destructive) {
        isDeleteConfirmationPresented = true
      } label: {
        Label(localized(.deleteVM), systemImage: "trash")
      }
      .disabled(!viewModel.canDeleteVM)
      .accessibilityIdentifier(LocalizationKey.deleteVM.rawValue)
    }
  }

  private var startActionKey: LocalizationKey {
    viewModel.metadata?.state == .error ? .retryStart : .startVM
  }

  private var vmIcon: some View {
    Image(systemName: "desktopcomputer")
      .font(.system(size: 42, weight: .regular))
      .foregroundStyle(.secondary)
      .frame(width: 56, height: 56)
      .accessibilityHidden(true)
  }

  private var consolePlaceholder: some View {
    VStack(spacing: 8) {
      Image(systemName: "display")
        .font(.system(size: 34, weight: .regular))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(localized(.consoleEmptyTitle))
        .font(.headline)
        .accessibilityIdentifier(LocalizationKey.consoleEmptyTitle.rawValue)
      Text(localized(.consoleEmptySubtitle))
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .accessibilityIdentifier(LocalizationKey.consoleEmptySubtitle.rawValue)
    }
    .padding(24)
  }

  private func detailRow(_ key: LocalizationKey, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(localized(key))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 78, alignment: .leading)
      Text(value)
        .font(.callout)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityIdentifier(key.rawValue)
    }
  }

  private func issueBanner(for decision: AdmissionDecision) -> some View {
    let issue = decision.blockers.first ?? decision.warnings.first
    return HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(localized(issueTitleKey(for: issue)))
        .font(.callout.weight(.medium))
      if let recoveryKey = issue?.recoveryKey {
        Text(localized(recoveryKey))
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
    )
  }

  private func noticeBanner(title: LocalizationKey, action: LocalizationKey) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(localized(title))
        .font(.callout.weight(.medium))
      Text(localized(action))
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
    )
  }

  private func handleISOSelection(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result, let url = urls.first else {
      return
    }
    if viewModel.metadata == nil {
      viewModel.createVM(from: url)
    } else {
      viewModel.replaceInstallMedia(from: url)
    }
  }

  private func issueTitleKey(for issue: AdmissionIssue?) -> LocalizationKey {
    guard let issue else {
      return .createUnavailable
    }

    switch issue.code {
    case .missingISO, .unreadableISO:
      return .isoMissing
    case .invalidISOExtension, .isoArchitectureMismatch, .unknownDistribution:
      return .isoInvalid
    case .insufficientDiskSpace:
      return .storageLow
    case .unsupportedHostArchitecture, .unsupportedMacOSVersion, .cpuTooLow, .cpuTooHigh,
      .memoryTooLow, .memoryTooHigh, .diskTooLow:
      return .configInvalid
    }
  }

  private func bootSourceKey(for bootSource: VMBootSource) -> LocalizationKey {
    switch bootSource {
    case .installMedia:
      return .bootInstallMedia
    case .disk:
      return .bootDisk
    }
  }

  private func installMediaName(for metadata: VMMetadata) -> String {
    guard let installMediaPath = metadata.installMediaPath else {
      return localizedValue(.bootDisk)
    }
    return URL(fileURLWithPath: installMediaPath).lastPathComponent
  }

  private func formattedBytes(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }

  private func localizedValue(_ key: LocalizationKey) -> String {
    NSLocalizedString(key.rawValue, comment: "")
  }

  private func localized(_ key: LocalizationKey) -> LocalizedStringKey {
    LocalizedStringKey(key.rawValue)
  }
}

#Preview {
  RootView()
}
