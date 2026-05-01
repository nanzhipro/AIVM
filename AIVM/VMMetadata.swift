import Foundation

enum VMState: String, Codable, CaseIterable, Identifiable {
  case draft = "Draft"
  case installing = "Installing"
  case stopped = "Stopped"
  case running = "Running"
  case error = "Error"

  var id: String { rawValue }

  var localizedKey: LocalizationKey {
    switch self {
    case .draft:
      return .notInstalled
    case .installing:
      return .installing
    case .stopped:
      return .stopped
    case .running:
      return .running
    case .error:
      return .needsAttention
    }
  }
}

enum VMBootSource: String, Codable, CaseIterable {
  case installMedia = "InstallMedia"
  case disk = "Disk"
}

enum VMNetworkMode: String, Codable, CaseIterable {
  case nat = "NAT"
}

struct VMResourceConfiguration: Codable, Equatable {
  static let light = VMResourceConfiguration(
    cpuCount: 2, memoryBytes: 4 * 1024 * 1024 * 1024, diskBytes: 32 * 1024 * 1024 * 1024)
  static let standard = VMResourceConfiguration(
    cpuCount: 4, memoryBytes: 8 * 1024 * 1024 * 1024, diskBytes: 64 * 1024 * 1024 * 1024)

  var cpuCount: Int
  var memoryBytes: UInt64
  var diskBytes: UInt64
}

struct VMMetadata: Codable, Equatable, Identifiable {
  static let currentSchemaVersion = 1

  var schemaVersion: Int
  var id: UUID
  var displayName: String
  var installMediaPath: String?
  var bootSource: VMBootSource
  var networkMode: VMNetworkMode
  var state: VMState
  var resources: VMResourceConfiguration
  var createdAt: Date
  var updatedAt: Date

  init(
    schemaVersion: Int = VMMetadata.currentSchemaVersion,
    id: UUID = UUID(),
    displayName: String,
    installMediaPath: String?,
    bootSource: VMBootSource = .installMedia,
    networkMode: VMNetworkMode = .nat,
    state: VMState = .draft,
    resources: VMResourceConfiguration = .standard,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.displayName = displayName
    self.installMediaPath = installMediaPath
    self.bootSource = bootSource
    self.networkMode = networkMode
    self.state = state
    self.resources = resources
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  var bundleName: String {
    "\(id.uuidString).vmbundle"
  }
}
