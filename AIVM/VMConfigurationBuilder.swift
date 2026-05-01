import Foundation
import Virtualization

enum VMConfigurationReadiness: Equatable {
  case unavailable
  case ready
  case failed
}

enum VMConfigurationBuilderError: Error, Equatable {
  case missingInstallMedia
  case missingInstallMediaPath
  case invalidMachineIdentifier
  case unsupportedNetworkMode
}

struct VMConfigurationBuildResult {
  let configuration: VZVirtualMachineConfiguration
  let diskImageURL: URL
  let machineIdentifierURL: URL
  let nvramURL: URL
  let installMediaURL: URL?
}

protocol VMConfigurationBuilding {
  @discardableResult
  func build(for metadata: VMMetadata) throws -> VMConfigurationBuildResult
}

final class VMConfigurationBuilder: VMConfigurationBuilding {
  private let store: VMBundleStore
  private let fileManager: FileManager
  private let configurationValidator: (VZVirtualMachineConfiguration) throws -> Void

  init(
    store: VMBundleStore,
    fileManager: FileManager = .default,
    configurationValidator: @escaping (VZVirtualMachineConfiguration) throws -> Void = {
      configuration in
      try configuration.validate()
    }
  ) {
    self.store = store
    self.fileManager = fileManager
    self.configurationValidator = configurationValidator
  }

  @discardableResult
  func build(for metadata: VMMetadata) throws -> VMConfigurationBuildResult {
    guard metadata.networkMode == .nat else {
      throw VMConfigurationBuilderError.unsupportedNetworkMode
    }

    try store.createBundle(for: metadata)

    let diskImageURL = store.layout.diskImageURL(for: metadata.id)
    let machineIdentifierURL = store.layout.machineIdentifierURL(for: metadata.id)
    let nvramURL = store.layout.nvramURL(for: metadata.id)

    try prepareDiskImage(at: diskImageURL, size: metadata.resources.diskBytes)
    let machineIdentifier = try loadOrCreateMachineIdentifier(at: machineIdentifierURL)
    let variableStore = try loadOrCreateVariableStore(at: nvramURL)

    let platform = VZGenericPlatformConfiguration()
    platform.machineIdentifier = machineIdentifier

    let bootLoader = VZEFIBootLoader()
    bootLoader.variableStore = variableStore

    let configuration = VZVirtualMachineConfiguration()
    configuration.platform = platform
    configuration.bootLoader = bootLoader
    configuration.cpuCount = metadata.resources.cpuCount
    configuration.memorySize = metadata.resources.memoryBytes
    configuration.storageDevices = try storageDevices(for: metadata, diskImageURL: diskImageURL)
    configuration.networkDevices = [natNetworkDevice()]
    configuration.graphicsDevices = [graphicsDevice()]
    configuration.keyboards = [VZUSBKeyboardConfiguration()]
    configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
    configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
    configuration.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

    try configurationValidator(configuration)

    return VMConfigurationBuildResult(
      configuration: configuration,
      diskImageURL: diskImageURL,
      machineIdentifierURL: machineIdentifierURL,
      nvramURL: nvramURL,
      installMediaURL: installMediaURL(for: metadata)
    )
  }

  private func storageDevices(for metadata: VMMetadata, diskImageURL: URL) throws
    -> [VZStorageDeviceConfiguration]
  {
    let diskAttachment = try VZDiskImageStorageDeviceAttachment(
      url: diskImageURL,
      readOnly: false,
      cachingMode: .automatic,
      synchronizationMode: .fsync
    )
    var devices: [VZStorageDeviceConfiguration] = [
      VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
    ]

    if metadata.bootSource == .installMedia {
      let isoURL = try requiredInstallMediaURL(for: metadata)
      let isoAttachment = try VZDiskImageStorageDeviceAttachment(url: isoURL, readOnly: true)
      devices.append(VZVirtioBlockDeviceConfiguration(attachment: isoAttachment))
    }

    return devices
  }

  private func prepareDiskImage(at url: URL, size: UInt64) throws {
    if !fileManager.fileExists(atPath: url.path) {
      guard fileManager.createFile(atPath: url.path, contents: nil) else {
        throw CocoaError(.fileWriteUnknown)
      }
    }

    let handle = try FileHandle(forWritingTo: url)
    defer {
      try? handle.close()
    }
    try handle.truncate(atOffset: size)
  }

  private func loadOrCreateMachineIdentifier(at url: URL) throws -> VZGenericMachineIdentifier {
    if fileManager.fileExists(atPath: url.path) {
      let data = try Data(contentsOf: url)
      guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: data) else {
        throw VMConfigurationBuilderError.invalidMachineIdentifier
      }
      return machineIdentifier
    }

    let machineIdentifier = VZGenericMachineIdentifier()
    try machineIdentifier.dataRepresentation.write(to: url, options: .atomic)
    return machineIdentifier
  }

  private func loadOrCreateVariableStore(at url: URL) throws -> VZEFIVariableStore {
    if fileManager.fileExists(atPath: url.path) {
      return VZEFIVariableStore(url: url)
    }
    return try VZEFIVariableStore(creatingVariableStoreAt: url, options: [])
  }

  private func natNetworkDevice() -> VZVirtioNetworkDeviceConfiguration {
    let device = VZVirtioNetworkDeviceConfiguration()
    device.attachment = VZNATNetworkDeviceAttachment()
    return device
  }

  private func graphicsDevice() -> VZVirtioGraphicsDeviceConfiguration {
    let device = VZVirtioGraphicsDeviceConfiguration()
    device.scanouts = [
      VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)
    ]
    return device
  }

  private func installMediaURL(for metadata: VMMetadata) -> URL? {
    guard let path = metadata.installMediaPath else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  private func requiredInstallMediaURL(for metadata: VMMetadata) throws -> URL {
    guard let isoURL = installMediaURL(for: metadata) else {
      throw VMConfigurationBuilderError.missingInstallMediaPath
    }
    guard fileManager.fileExists(atPath: isoURL.path) else {
      throw VMConfigurationBuilderError.missingInstallMedia
    }
    return isoURL
  }
}
