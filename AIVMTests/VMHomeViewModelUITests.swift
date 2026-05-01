import XCTest
import Virtualization
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
    private func makeViewModel(store: VMBundleStore, root: URL) -> VMHomeViewModel {
        VMHomeViewModel(
            store: store,
            configurationBuilder: Phase5FakeConfigurationBuilder(result: .success(makeBuildResult(root: root))),
            lifecycleController: Phase5FakeLifecycleController(),
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