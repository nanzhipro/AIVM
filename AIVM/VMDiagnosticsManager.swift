import AppKit
import Foundation

struct VMDiagnosticSnapshot: Codable, Equatable {
  struct Resources: Codable, Equatable {
    var cpuCount: Int
    var memoryBytes: UInt64
    var diskBytes: UInt64
  }

  struct Artifacts: Codable, Equatable {
    var bundleName: String
    var diskImageExists: Bool
    var machineIdentifierExists: Bool
    var nvramExists: Bool
  }

  var generatedAt: Date
  var appVersion: String
  var macOSVersion: String
  var hostArchitecture: String
  var vmID: UUID
  var vmState: VMState
  var bootSource: VMBootSource
  var networkMode: VMNetworkMode
  var resources: Resources
  var installMediaName: String?
  var artifacts: Artifacts
}

enum VMDiagnosticsError: Error, Equatable {
  case unsafeLogsPath(URL)
}

protocol VMDiagnosticsProviding {
  @discardableResult
  func writeSnapshot(for metadata: VMMetadata, host: HostEnvironment) throws -> URL

  @discardableResult
  func openDiagnosticsDirectory(for metadata: VMMetadata, host: HostEnvironment) throws -> URL
}

final class VMDiagnosticsManager: VMDiagnosticsProviding {
  private let store: VMBundleStore
  private let fileManager: FileManager
  private let workspace: NSWorkspace
  private let appVersionProvider: () -> String
  private let now: () -> Date

  init(
    store: VMBundleStore,
    fileManager: FileManager = .default,
    workspace: NSWorkspace = .shared,
    appVersionProvider: @escaping () -> String = VMDiagnosticsManager.defaultAppVersion,
    now: @escaping () -> Date = { Date() }
  ) {
    self.store = store
    self.fileManager = fileManager
    self.workspace = workspace
    self.appVersionProvider = appVersionProvider
    self.now = now
  }

  @discardableResult
  func writeSnapshot(for metadata: VMMetadata, host: HostEnvironment) throws -> URL {
    let logsURL = store.layout.logsURL(for: metadata.id)
    guard store.layout.contains(logsURL) else {
      throw VMDiagnosticsError.unsafeLogsPath(logsURL)
    }

    try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
    let snapshot = makeSnapshot(for: metadata, host: host)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let snapshotURL = logsURL.appendingPathComponent("diagnostics.json", isDirectory: false)
    try encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)
    return snapshotURL
  }

  @discardableResult
  func openDiagnosticsDirectory(for metadata: VMMetadata, host: HostEnvironment) throws -> URL {
    let snapshotURL = try writeSnapshot(for: metadata, host: host)
    let logsURL = snapshotURL.deletingLastPathComponent()
    workspace.open(logsURL)
    return logsURL
  }

  private func makeSnapshot(for metadata: VMMetadata, host: HostEnvironment) -> VMDiagnosticSnapshot
  {
    VMDiagnosticSnapshot(
      generatedAt: now(),
      appVersion: appVersionProvider(),
      macOSVersion: Self.versionString(host.macOSVersion),
      hostArchitecture: host.architecture,
      vmID: metadata.id,
      vmState: metadata.state,
      bootSource: metadata.bootSource,
      networkMode: metadata.networkMode,
      resources: VMDiagnosticSnapshot.Resources(
        cpuCount: metadata.resources.cpuCount,
        memoryBytes: metadata.resources.memoryBytes,
        diskBytes: metadata.resources.diskBytes
      ),
      installMediaName: metadata.installMediaPath.map {
        URL(fileURLWithPath: $0).lastPathComponent
      },
      artifacts: VMDiagnosticSnapshot.Artifacts(
        bundleName: metadata.bundleName,
        diskImageExists: fileManager.fileExists(
          atPath: store.layout.diskImageURL(for: metadata.id).path),
        machineIdentifierExists: fileManager.fileExists(
          atPath: store.layout.machineIdentifierURL(for: metadata.id).path),
        nvramExists: fileManager.fileExists(atPath: store.layout.nvramURL(for: metadata.id).path)
      )
    )
  }

  private static func defaultAppVersion() -> String {
    let info = Bundle.main.infoDictionary
    return info?["CFBundleShortVersionString"] as? String
      ?? info?["CFBundleVersion"] as? String
      ?? "development"
  }

  private static func versionString(_ version: OperatingSystemVersion) -> String {
    "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
  }
}
