import Virtualization
import XCTest

@testable import AIVM

final class VirtualizationConfigurationBuilderTests: XCTestCase {
  private var temporaryRoots: [URL] = []

  override func tearDown() {
    for root in temporaryRoots {
      try? FileManager.default.removeItem(at: root)
    }
    temporaryRoots.removeAll()
    super.tearDown()
  }

  func testInstallConfigurationCreatesValidatedDeviceGraphAndArtifacts() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
    let metadata = makeMetadata(installMediaPath: isoURL.path)
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    let result = try builder.build(for: metadata)
    let configuration = result.configuration

    XCTAssertEqual(configuration.cpuCount, metadata.resources.cpuCount)
    XCTAssertEqual(configuration.memorySize, metadata.resources.memoryBytes)
    XCTAssertTrue(configuration.platform is VZGenericPlatformConfiguration)
    XCTAssertTrue(configuration.bootLoader is VZEFIBootLoader)
    XCTAssertEqual(configuration.storageDevices.count, 2)
    XCTAssertEqual(configuration.networkDevices.count, 1)
    XCTAssertTrue(configuration.networkDevices.first is VZVirtioNetworkDeviceConfiguration)
    XCTAssertEqual(configuration.graphicsDevices.count, 1)
    XCTAssertEqual(configuration.keyboards.count, 1)
    XCTAssertEqual(configuration.pointingDevices.count, 1)
    XCTAssertEqual(configuration.entropyDevices.count, 1)
    XCTAssertEqual(configuration.memoryBalloonDevices.count, 1)
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.diskImageURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.machineIdentifierURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.nvramURL.path))
    XCTAssertEqual(result.installMediaURL, isoURL)
    XCTAssertEqual(try logicalSize(of: result.diskImageURL), metadata.resources.diskBytes)
  }

  func testConfigurationValidateIsCalledWhenEntitlementIsAvailable() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
    let metadata = makeMetadata(installMediaPath: isoURL.path)
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    let result = try builder.build(for: metadata)

    do {
      try result.configuration.validate()
    } catch {
      let message = String(describing: error)
      if message.contains("com.apple.security.virtualization") {
        throw XCTSkip(
          "Unsigned test host does not expose the virtualization entitlement to VZ validate.")
      }
      throw error
    }
  }

  func testDiskBootOmitsInstallMediaAttachment() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(installMediaPath: nil, bootSource: .disk)
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    let result = try builder.build(for: metadata)

    XCTAssertEqual(result.configuration.storageDevices.count, 1)
    XCTAssertNil(result.installMediaURL)
  }

  func testRepeatedBuildsReuseMachineIdentifier() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
    let metadata = makeMetadata(installMediaPath: isoURL.path)
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    let first = try builder.build(for: metadata)
    let firstData = try Data(contentsOf: first.machineIdentifierURL)
    let second = try builder.build(for: metadata)
    let secondData = try Data(contentsOf: second.machineIdentifierURL)

    XCTAssertEqual(second.machineIdentifierURL, first.machineIdentifierURL)
    XCTAssertEqual(secondData, firstData)
  }

  func testMissingInstallMediaIsRejected() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(installMediaPath: root.appendingPathComponent("missing.iso").path)
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    XCTAssertThrowsError(try builder.build(for: metadata)) { error in
      XCTAssertEqual(error as? VMConfigurationBuilderError, .missingInstallMedia)
    }
  }

  func testCorruptMachineIdentifierIsRejected() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
    let metadata = makeMetadata(installMediaPath: isoURL.path)
    try store.createBundle(for: metadata)
    try Data("not-a-machine-id".utf8).write(to: store.layout.machineIdentifierURL(for: metadata.id))
    let builder = VMConfigurationBuilder(store: store, configurationValidator: { _ in })

    XCTAssertThrowsError(try builder.build(for: metadata)) { error in
      XCTAssertEqual(error as? VMConfigurationBuilderError, .invalidMachineIdentifier)
    }
  }

  @MainActor
  func testViewModelRecordsReadyConfigurationReadiness() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(installMediaPath: nil, bootSource: .disk)
    try store.createBundle(for: metadata)

    let viewModel = VMHomeViewModel(
      store: store,
      configurationBuilder: FakeConfigurationBuilder(result: .success(makeBuildResult(root: root))),
      hostEnvironmentProvider: { self.supportedHost() }
    )

    XCTAssertEqual(viewModel.configurationReadiness, .ready)
  }

  @MainActor
  func testViewModelRecordsFailedConfigurationReadiness() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(installMediaPath: nil, bootSource: .disk)
    try store.createBundle(for: metadata)

    let viewModel = VMHomeViewModel(
      store: store,
      configurationBuilder: FakeConfigurationBuilder(
        result: .failure(VMConfigurationBuilderError.missingInstallMedia)),
      hostEnvironmentProvider: { self.supportedHost() }
    )

    XCTAssertEqual(viewModel.configurationReadiness, .failed)
  }

  private var gib: UInt64 { 1024 * 1024 * 1024 }

  private func makeMetadata(
    installMediaPath: String?,
    bootSource: VMBootSource = .installMedia
  ) -> VMMetadata {
    VMMetadata(
      id: UUID(),
      displayName: "Ubuntu",
      installMediaPath: installMediaPath,
      bootSource: bootSource,
      resources: VMResourceConfiguration(cpuCount: 2, memoryBytes: 4 * gib, diskBytes: 32 * gib),
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
    )
  }

  private func makeISO(named name: String) throws -> URL {
    let root = makeTemporaryRoot()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("iso-source", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("AIVM test ISO".utf8).write(to: source.appendingPathComponent("README.txt"))

    let url = root.appendingPathComponent(name, isDirectory: false)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
    process.arguments = ["makehybrid", "-iso", "-joliet", "-o", url.path, source.path]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw CocoaError(.fileWriteUnknown)
    }
    return url
  }

  private func makeTemporaryRoot() -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("AIVMVirtualizationConfigurationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    temporaryRoots.append(root)
    return root
  }

  private func logicalSize(of url: URL) throws -> UInt64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return attributes[.size] as? UInt64 ?? UInt64(attributes[.size] as? Int64 ?? 0)
  }

  private func supportedHost() -> HostEnvironment {
    HostEnvironment(
      architecture: "arm64",
      macOSVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0),
      cpuCoreCount: 8,
      memoryBytes: 16 * gib,
      availableDiskBytes: 256 * gib
    )
  }

  private func makeBuildResult(root: URL) -> VMConfigurationBuildResult {
    VMConfigurationBuildResult(
      configuration: VZVirtualMachineConfiguration(),
      diskImageURL: root.appendingPathComponent("Disk.img"),
      machineIdentifierURL: root.appendingPathComponent("MachineIdentifier"),
      nvramURL: root.appendingPathComponent("NVRAM"),
      installMediaURL: nil
    )
  }
}

private final class FakeConfigurationBuilder: VMConfigurationBuilding {
  private let result: Result<VMConfigurationBuildResult, Error>

  init(result: Result<VMConfigurationBuildResult, Error>) {
    self.result = result
  }

  func build(for metadata: VMMetadata) throws -> VMConfigurationBuildResult {
    try result.get()
  }
}
