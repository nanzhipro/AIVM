import Foundation
import OSLog
import Virtualization

enum VMLifecycleError: Error, Equatable {
    case invalidTransition(VMState)
    case noActiveVirtualMachine
    case virtualMachineCannotStart
    case virtualMachineCannotStop
}

struct VMStateMachine {
    static func canStart(from state: VMState) -> Bool {
        switch state {
        case .draft, .stopped, .error:
            return true
        case .installing, .running:
            return false
        }
    }

    static func canStop(from state: VMState) -> Bool {
        switch state {
        case .installing, .running:
            return true
        case .draft, .stopped, .error:
            return false
        }
    }

    static func startedState(for metadata: VMMetadata) -> VMState {
        metadata.bootSource == .installMedia ? .installing : .running
    }
}

@MainActor
protocol VMLifecycleControlling {
    var displayVirtualMachine: VZVirtualMachine? { get }

    func start(metadata: VMMetadata) async throws -> VMMetadata
    func stop(metadata: VMMetadata) async throws -> VMMetadata
}

@MainActor
protocol VirtualMachineOperating: AnyObject {
    var state: VZVirtualMachine.State { get }
    var canStart: Bool { get }
    var canStop: Bool { get }
    var displayVirtualMachine: VZVirtualMachine? { get }

    func start() async throws
    func stop() async throws
}

@MainActor
final class VZVirtualMachineAdapter: VirtualMachineOperating {
    private let virtualMachine: VZVirtualMachine

    init(configuration: VZVirtualMachineConfiguration) {
        self.virtualMachine = VZVirtualMachine(configuration: configuration)
    }

    var state: VZVirtualMachine.State {
        virtualMachine.state
    }

    var canStart: Bool {
        virtualMachine.canStart
    }

    var canStop: Bool {
        virtualMachine.canStop
    }

    var displayVirtualMachine: VZVirtualMachine? {
        virtualMachine
    }

    func start() async throws {
        try await virtualMachine.start()
    }

    func stop() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            virtualMachine.stop { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

@MainActor
final class VMLifecycleController: VMLifecycleControlling {
    typealias VirtualMachineFactory = @MainActor (VZVirtualMachineConfiguration) -> VirtualMachineOperating

    private let store: VMBundleStore
    private let configurationBuilder: VMConfigurationBuilding
    private let makeVirtualMachine: VirtualMachineFactory
    private let logger: Logger
    private var activeMachine: VirtualMachineOperating?

    var displayVirtualMachine: VZVirtualMachine? {
        activeMachine?.displayVirtualMachine
    }

    init(
        store: VMBundleStore,
        configurationBuilder: VMConfigurationBuilding,
        makeVirtualMachine: @escaping VirtualMachineFactory = { configuration in
            VZVirtualMachineAdapter(configuration: configuration)
        },
        logger: Logger = Logger(subsystem: "pro.nanzhi.AIVM", category: "VMLifecycle")
    ) {
        self.store = store
        self.configurationBuilder = configurationBuilder
        self.makeVirtualMachine = makeVirtualMachine
        self.logger = logger
    }

    func start(metadata: VMMetadata) async throws -> VMMetadata {
        guard VMStateMachine.canStart(from: metadata.state) else {
            throw VMLifecycleError.invalidTransition(metadata.state)
        }

        logger.info("VM start requested id=\(metadata.id.uuidString, privacy: .public) state=\(metadata.state.rawValue, privacy: .public)")

        do {
            let buildResult = try configurationBuilder.build(for: metadata)
            let virtualMachine = makeVirtualMachine(buildResult.configuration)
            guard virtualMachine.canStart else {
                throw VMLifecycleError.virtualMachineCannotStart
            }
            try await virtualMachine.start()
            activeMachine = virtualMachine
            let updated = try persist(metadata, state: VMStateMachine.startedState(for: metadata))
            logger.info("VM start succeeded id=\(metadata.id.uuidString, privacy: .public) state=\(updated.state.rawValue, privacy: .public)")
            return updated
        } catch {
            _ = try? persist(metadata, state: .error)
            logger.error("VM start failed id=\(metadata.id.uuidString, privacy: .public)")
            throw error
        }
    }

    func stop(metadata: VMMetadata) async throws -> VMMetadata {
        guard VMStateMachine.canStop(from: metadata.state) else {
            throw VMLifecycleError.invalidTransition(metadata.state)
        }
        guard let activeMachine else {
            throw VMLifecycleError.noActiveVirtualMachine
        }

        logger.info("VM stop requested id=\(metadata.id.uuidString, privacy: .public) state=\(metadata.state.rawValue, privacy: .public)")

        do {
            guard activeMachine.canStop else {
                throw VMLifecycleError.virtualMachineCannotStop
            }
            try await activeMachine.stop()
            self.activeMachine = nil
            let updated = try persist(metadata, state: .stopped)
            logger.info("VM stop succeeded id=\(metadata.id.uuidString, privacy: .public)")
            return updated
        } catch {
            _ = try? persist(metadata, state: .error)
            logger.error("VM stop failed id=\(metadata.id.uuidString, privacy: .public)")
            throw error
        }
    }

    private func persist(_ metadata: VMMetadata, state: VMState) throws -> VMMetadata {
        var updated = metadata
        updated.state = state
        updated.updatedAt = Date()
        try store.save(updated)
        return updated
    }
}