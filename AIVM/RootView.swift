import SwiftUI

struct RootView: View {
    private let statusKeys: [LocalizationKey] = [
        .notInstalled,
        .installing,
        .stopped,
        .running,
        .needsAttention
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
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
            } label: {
                Label(localized(.createVM), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(LocalizationKey.createVM.rawValue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var content: some View {
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

            HStack(spacing: 10) {
                Button {
                } label: {
                    Label(localized(.selectISO), systemImage: "opticaldiscdrive")
                }
                .accessibilityIdentifier(LocalizationKey.selectISO.rawValue)

                Button {
                } label: {
                    Label(localized(.viewLogs), systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier(LocalizationKey.viewLogs.rawValue)
            }

            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(statusKeys, id: \.rawValue) { key in
                        Text(localized(key))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
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

    private func localized(_ key: LocalizationKey) -> LocalizedStringKey {
        LocalizedStringKey(key.rawValue)
    }
}

#Preview {
    RootView()
}
