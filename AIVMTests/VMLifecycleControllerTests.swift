import XCTest
import Virtualization
@testable import AIVM

final class VMLifecycleControllerTests: XCTestCase {
    private var temporaryRoots: [URL] = []

    override func tearDown() {
        for root in temporaryRoots {
            try? FileManager.default.removeItem(at: root)
        }
        temporaryRoots.removeAll()
        super.tearDown()
    }

    func testStateMachineStartAndStopPermissions() {
        XCTAssertTrue(VMStateMachine.canStart(from: .draft))
        XCTAssertTrue(VMStateMachine.canStart(from: .stopped))
        XCTAssertTrue(VMStateMachine.canStart(from: .error))
        XCTAssertFalse(VMStateMachine.canStart(from: .installing))
        XCTAssertFalse(VMStateMachine.canStart(from: .running))

        XCTAssertFalse(VMStateMachine.canStop(from: .draft))
        XCTAssertFalse(VMStateMachine.canStop(from: .stopped))
        XCTAssertFalse(VMStateMachine.canStop(from: .error))
        XCTAssertTrue(VMStateMachine.canStop(from: .installing))
        XCTAssertTrue(VMStateMachine.canStop(from: .running))
    }

    @MainActor
    func testInstallMediaStartPersistsInstalling() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .draft, bootSource: .installMedia)
        try context.store.createBundle(for: metadata)
        let machine = FakeVirtualMachine()
        let controller = makeController(context: context, machine: machine)

        let updated = try await controller.start(metadata: metadata)

        XCTAssertEqual(updated.state, .installing)
        XCTAssertEqual(try context.store.load(id: metadata.id).state, .installing)
        XCTAssertEqual(machine.startCallCount, 1)
    }

    @MainActor
    func testDiskStartPersistsRunning() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .stopped, bootSource: .disk)
        try context.store.createBundle(for: metadata)
        let controller = makeController(context: context, machine: FakeVirtualMachine())

        let updated = try await controller.start(metadata: metadata)

        XCTAssertEqual(updated.state, .running)
        XCTAssertEqual(try context.store.load(id: metadata.id).state, .running)
    }

    @MainActor
    func testInvalidStartTransitionDoesNotMutateMetadata() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .running, bootSource: .disk)
        try context.store.createBundle(for: metadata)
        let controller = makeController(context: context, machine: FakeVirtualMachine())

        do {
            _ = try await controller.start(metadata: metadata)
            XCTFail("Expected invalid transition")
        } catch {
            XCTAssertEqual(error as? VMLifecycleError, .invalidTransition(.running))
        }

        XCTAssertEqual(try context.store.load(id: metadata.id).state, .running)
    }

    @MainActor
    func testBuilderFailurePersistsError() async throws {
        let context = makeContext(builderResult: .failure(VMConfigurationBuilderError.missingInstallMedia))
        let metadata = makeMetadata(state: .draft, bootSource: .installMedia)
        try context.store.createBundle(for: metadata)
        let controller = makeController(context: context, machine: FakeVirtualMachine())

        do {
            _ = try await controller.start(metadata: metadata)
            XCTFail("Expected builder failure")
        } catch {
            XCTAssertEqual(error as? VMConfigurationBuilderError, .missingInstallMedia)
        }

        XCTAssertEqual(try context.store.load(id: metadata.id).state, .error)
    }

    @MainActor
    func testStartFailurePersistsError() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .draft, bootSource: .installMedia)
        try context.store.createBundle(for: metadata)
        let machine = FakeVirtualMachine(startError: TestLifecycleError.start)
        let controller = makeController(context: context, machine: machine)

        do {
            _ = try await controller.start(metadata: metadata)
            XCTFail("Expected start failure")
        } catch {
            XCTAssertEqual(error as? TestLifecycleError, .start)
        }

        XCTAssertEqual(try context.store.load(id: metadata.id).state, .error)
    }

    @MainActor
    func testStopPersistsStopped() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .stopped, bootSource: .disk)
        try context.store.createBundle(for: metadata)
        let machine = FakeVirtualMachine()
        let controller = makeController(context: context, machine: machine)

        let running = try await controller.start(metadata: metadata)
        let stopped = try await controller.stop(metadata: running)

        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertEqual(try context.store.load(id: metadata.id).state, .stopped)
        XCTAssertEqual(machine.stopCallCount, 1)
    }

    @MainActor
    func testStopFailurePersistsError() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .stopped, bootSource: .disk)
        try context.store.createBundle(for: metadata)
        let machine = FakeVirtualMachine(stopError: TestLifecycleError.stop)
        let controller = makeController(context: context, machine: machine)

        let running = try await controller.start(metadata: metadata)
        do {
            _ = try await controller.stop(metadata: running)
            XCTFail("Expected stop failure")
        } catch {
            XCTAssertEqual(error as? TestLifecycleError, .stop)
        }

        XCTAssertEqual(try context.store.load(id: metadata.id).state, .error)
    }

    @MainActor
    func testStopWithoutActiveMachineIsRejectedWithoutMutation() async throws {
        let context = makeContext()
        let metadata = makeMetadata(state: .running, bootSource: .disk)
        try context.store.createBundle(for: metadata)
        let controller = makeController(context: context, machine: FakeVirtualMachine())

        do {
            _ = try await controller.stop(metadata: metadata)
            XCTFail("Expected missing active VM")
        } catch {
            XCTAssertEqual(error as? VMLifecycleError, .noActiveVirtualMachine)
        }

        XCTAssertEqual(try context.store.load(id: metadata.id).state, .running)
    }

    @MainActor
    func testViewModelStartActionUsesLifecycleController() async throws {
        let root = makeTemporaryRoot()
        let store = VMBundleStore(rootDirectory: root)
        let metadata = makeMetadata(state: .draft, bootSource: .disk)
        try store.createBundle(for: metadata)
        let lifecycle = FakeLifecycleController(startState: .running, stopState: .stopped)
        let viewModel = VMHomeViewModel(
            store: store,
            configurationBuilder: FakeConfigurationBuilder(result: .success(makeBuildResult(root: root))),
            lifecycleController: lifecycle,
            hostEnvironmentProvider: { self.supportedHost() }
        )

        XCTAssertTrue(viewModel.canStartVM)
        await viewModel.startCurrentVM()

        XCTAssertEqual(viewModel.metadata?.state, .running)
        XCTAssertEqual(lifecycle.startCallCount, 1)
    }

    @MainActor
    func testViewModelStopActionUsesLifecycleController() async throws {
        let root = makeTemporaryRoot()
        let store = VMBundleStore(rootDirectory: root)
        let metadata = makeMetadata(state: .running, bootSource: .disk)
        try store.createBundle(for: metadata)
        let lifecycle = FakeLifecycleController(startState: .running, stopState: .stopped)
        let viewModel = VMHomeViewModel(
            store: store,
            configurationBuilder: FakeConfigurationBuilder(result: .success(makeBuildResult(root: root))),
            lifecycleController: lifecycle,
            hostEnvironmentProvider: { self.supportedHost() }
        )

        XCTAssertTrue(viewModel.canStopVM)
        await viewModel.stopCurrentVM()

        XCTAssertEqual(viewModel.metadata?.state, .stopped)
        XCTAssertEqual(lifecycle.stopCallCount, 1)
    }

    private var gib: UInt64 { 1024 * 1024 * 1024 }

    private func makeContext(
        builderResult: Result<VMConfigurationBuildResult, Error>? = nil
    ) -> LifecycleContext {
        let root = makeTemporaryRoot()
        let store = VMBundleStore(rootDirectory: root)
        let result = builderResult ?? .success(makeBuildResult(root: root))
        return LifecycleContext(root: root, store: store, builder: FakeConfigurationBuilder(result: result))
    }

    @MainActor
    private func makeController(context: LifecycleContext, machine: FakeVirtualMachine) -> VMLifecycleController {
        VMLifecycleController(
            store: context.store,
            configurationBuilder: context.builder,
            makeVirtualMachine: { _ in machine }
        )
    }

    private func makeMetadata(state: VMState, bootSource: VMBootSource) -> VMMetadata {
        VMMetadata(
            id: UUID(),
            displayName: "Ubuntu",
            installMediaPath: bootSource == .installMedia ? "/tmp/ubuntu-arm64.iso" : nil,
            bootSource: bootSource,
            state: state,
            resources: VMResourceConfiguration(cpuCount: 2, memoryBytes: 4 * gib, diskBytes: 32 * gib),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
        )
    }

    private func makeTemporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIVMLifecycleTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryRoots.append(root)
        return root
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

private struct LifecycleContext {
    let root: URL
    let store: VMBundleStore
    let builder: FakeConfigurationBuilder
}

private enum TestLifecycleError: Error, Equatable {
    case start
    case stop
}

@MainActor
private final class FakeVirtualMachine: VirtualMachineOperating {
    var state: VZVirtualMachine.State = .stopped
    var canStart: Bool
    var canStop: Bool
    private let startError: Error?
    private let stopError: Error?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(canStart: Bool = true, canStop: Bool = true, startError: Error? = nil, stopError: Error? = nil) {
        self.canStart = canStart
        self.canStop = canStop
        self.startError = startError
        self.stopError = stopError
    }

    func start() async throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        state = .running
    }

    func stop() async throws {
        stopCallCount += 1
        if let stopError {
            throw stopError
        }
        state = .stopped
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

@MainActor
private final class FakeLifecycleController: VMLifecycleControlling {
    private let startState: VMState
    private let stopState: VMState
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(startState: VMState, stopState: VMState) {
        self.startState = startState
        self.stopState = stopState
    }

    func start(metadata: VMMetadata) async throws -> VMMetadata {
        startCallCount += 1
        var updated = metadata
        updated.state = startState
        return updated
    }

    func stop(metadata: VMMetadata) async throws -> VMMetadata {
        stopCallCount += 1
        var updated = metadata
        updated.state = stopState
        return updated
    }
}