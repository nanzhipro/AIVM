import Virtualization
import XCTest

@testable import AIVM

final class VMHomeViewModelUITests: XCTestCase {
  private var temporaryRoots: [URL] = []

  override func tearDown() {
    for root in temporaryRoots {
      try? FileManager.default.removeItem(at: root)
    }
    temporaryRoots.removeAll()
    super.tearDown()
  }

  @MainActor
  func testCreateVMFromValidARM64ISOStoresDraftMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-desktop-arm64.iso")
    let viewModel = makeViewModel(store: store, root: root)

    viewModel.createVM(from: isoURL)

    let metadata = try XCTUnwrap(viewModel.metadata)
    XCTAssertEqual(metadata.displayName, "ubuntu-desktop-arm64")
    XCTAssertEqual(metadata.installMediaPath, isoURL.path)
    XCTAssertEqual(metadata.bootSource, .installMedia)
    XCTAssertEqual(metadata.networkMode, .nat)
    XCTAssertEqual(metadata.state, .draft)
    XCTAssertEqual(metadata.resources, .standard)
    XCTAssertFalse(viewModel.canCreateVM)
    XCTAssertEqual(try store.loadAll().count, 1)
  }

  @MainActor
  func testCreateVMWithAMD64ISOIsBlockedWithoutMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let isoURL = try makeISO(named: "ubuntu-desktop-amd64.iso")
    let viewModel = makeViewModel(store: store, root: root)

    viewModel.createVM(from: isoURL)

    XCTAssertNil(viewModel.metadata)
    XCTAssertTrue(viewModel.creationAdmission.contains(.isoArchitectureMismatch))
    XCTAssertTrue(try store.loadAll().isEmpty)
  }

  @MainActor
  func testCreateVMDoesNotReplaceExistingMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let existing = makeMetadata(displayName: "Existing", state: .stopped)
    try store.createBundle(for: existing)
    let isoURL = try makeISO(named: "ubuntu-desktop-arm64.iso")
    let viewModel = makeViewModel(store: store, root: root)

    viewModel.createVM(from: isoURL)

    XCTAssertEqual(viewModel.metadata?.id, existing.id)
    XCTAssertEqual(try store.loadAll().map(\.id), [existing.id])
  }

  @MainActor
  func testDeleteCurrentVMRemovesBundleMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .stopped)
    try store.createBundle(for: metadata)
    let viewModel = makeViewModel(store: store, root: root)

    XCTAssertTrue(viewModel.canDeleteVM)
    viewModel.deleteCurrentVM()

    XCTAssertNil(viewModel.metadata)
    XCTAssertTrue(try store.loadAll().isEmpty)
    XCTAssertFalse(viewModel.canDeleteVM)
  }

  @MainActor
  func testReplaceInstallMediaUpdatesRecoverableMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .error)
    try store.createBundle(for: metadata)
    let replacementISO = try makeISO(named: "ubuntu-desktop-arm64.iso")
    let viewModel = makeViewModel(store: store, root: root)

    XCTAssertTrue(viewModel.canReplaceInstallMedia)
    viewModel.replaceInstallMedia(from: replacementISO)

    let updated = try XCTUnwrap(viewModel.metadata)
    XCTAssertEqual(updated.installMediaPath, replacementISO.path)
    XCTAssertEqual(updated.bootSource, .installMedia)
    XCTAssertEqual(updated.state, .draft)
    XCTAssertEqual(try store.load(id: metadata.id).installMediaPath, replacementISO.path)
  }

  @MainActor
  func testInvalidReplacementISODoesNotMutateMetadata() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .error)
    try store.createBundle(for: metadata)
    let replacementISO = try makeISO(named: "ubuntu-desktop-amd64.iso")
    let viewModel = makeViewModel(store: store, root: root)

    viewModel.replaceInstallMedia(from: replacementISO)

    XCTAssertEqual(viewModel.metadata, metadata)
    XCTAssertEqual(try store.load(id: metadata.id), metadata)
    XCTAssertTrue(viewModel.creationAdmission.contains(.isoArchitectureMismatch))
  }

  @MainActor
  func testOpenDiagnosticsUsesInjectedProvider() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .error)
    try store.createBundle(for: metadata)
    let diagnostics = Phase6FakeDiagnosticsProvider()
    let viewModel = makeViewModel(store: store, root: root, diagnosticsProvider: diagnostics)

    viewModel.openDiagnostics()

    XCTAssertEqual(diagnostics.openCallCount, 1)
    XCTAssertEqual(diagnostics.openedMetadataID, metadata.id)
  }

  func testDiagnosticsSnapshotIsLocalAndOmitsFullInstallMediaPath() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .error)
    try store.createBundle(for: metadata)
    FileManager.default.createFile(
      atPath: store.layout.diskImageURL(for: metadata.id).path, contents: Data())
    let manager = VMDiagnosticsManager(
      store: store,
      appVersionProvider: { "test-version" },
      now: { Date(timeIntervalSince1970: 1_700_000_000) }
    )

    let snapshotURL = try manager.writeSnapshot(for: metadata, host: supportedHost())

    XCTAssertEqual(snapshotURL.deletingLastPathComponent(), store.layout.logsURL(for: metadata.id))
    let data = try Data(contentsOf: snapshotURL)
    let snapshot = try JSONDecoder.aivmDiagnostics.decode(VMDiagnosticSnapshot.self, from: data)
    XCTAssertEqual(snapshot.vmID, metadata.id)
    XCTAssertEqual(snapshot.vmState, .error)
    XCTAssertEqual(snapshot.installMediaName, "ubuntu-desktop-arm64.iso")
    XCTAssertEqual(snapshot.appVersion, "test-version")
    XCTAssertTrue(snapshot.artifacts.diskImageExists)
    let json = String(decoding: data, as: UTF8.self)
    XCTAssertFalse(json.contains(metadata.installMediaPath ?? ""))
  }

  @MainActor
  func testActionAvailabilityMatchesLoadedState() throws {
    let root = makeTemporaryRoot()
    let store = VMBundleStore(rootDirectory: root)
    let metadata = makeMetadata(displayName: "Ubuntu", state: .running)
    try store.createBundle(for: metadata)
    let viewModel = makeViewModel(store: store, root: root)

    XCTAssertFalse(viewModel.canStartVM)
    XCTAssertTrue(viewModel.canStopVM)
    XCTAssertFalse(viewModel.canDeleteVM)
  }

  private var gib: UInt64 { 1024 * 1024 * 1024 }

  @MainActor
  private func makeViewModel(
    store: VMBundleStore,
    root: URL,
    diagnosticsProvider: VMDiagnosticsProviding? = nil
  ) -> VMHomeViewModel {
    VMHomeViewModel(
      store: store,
      configurationBuilder: Phase5FakeConfigurationBuilder(
        result: .success(makeBuildResult(root: root))),
      lifecycleController: Phase5FakeLifecycleController(),
      diagnosticsProvider: diagnosticsProvider,
      hostEnvironmentProvider: { self.supportedHost() }
    )
  }

  private func makeMetadata(displayName: String, state: VMState) -> VMMetadata {
    VMMetadata(
      id: UUID(),
      displayName: displayName,
      installMediaPath: "/tmp/ubuntu-desktop-arm64.iso",
      bootSource: .installMedia,
      networkMode: .nat,
      state: state,
      resources: .standard,
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
    )
  }

  private func makeTemporaryRoot() -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("AIVMPhase5Tests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    temporaryRoots.append(root)
    return root
  }

  private func makeISO(named name: String) throws -> URL {
    let directory = makeTemporaryRoot()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(name)
    try Data("iso".utf8).write(to: url)
    return url
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

  private func supportedHost() -> HostEnvironment {
    HostEnvironment(
      architecture: "arm64",
      macOSVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0),
      cpuCoreCount: 8,
      memoryBytes: 16 * gib,
      availableDiskBytes: 256 * gib
    )
  }
}

extension JSONDecoder {
  fileprivate static var aivmDiagnostics: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

private final class Phase5FakeConfigurationBuilder: VMConfigurationBuilding {
  private let result: Result<VMConfigurationBuildResult, Error>

  init(result: Result<VMConfigurationBuildResult, Error>) {
    self.result = result
  }

  func build(for metadata: VMMetadata) throws -> VMConfigurationBuildResult {
    try result.get()
  }
}

@MainActor
private final class Phase5FakeLifecycleController: VMLifecycleControlling {
  var displayVirtualMachine: VZVirtualMachine? { nil }

  func start(metadata: VMMetadata) async throws -> VMMetadata {
    metadata
  }

  func stop(metadata: VMMetadata) async throws -> VMMetadata {
    metadata
  }
}

private final class Phase6FakeDiagnosticsProvider: VMDiagnosticsProviding {
  private(set) var openCallCount = 0
  private(set) var openedMetadataID: UUID?

  func writeSnapshot(for metadata: VMMetadata, host: HostEnvironment) throws -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("diagnostics.json")
  }

  func openDiagnosticsDirectory(for metadata: VMMetadata, host: HostEnvironment) throws -> URL {
    openCallCount += 1
    openedMetadataID = metadata.id
    return FileManager.default.temporaryDirectory
  }
}
