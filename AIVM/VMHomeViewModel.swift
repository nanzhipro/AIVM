import Foundation
import Combine
import OSLog
import Virtualization

@MainActor
final class VMHomeViewModel: ObservableObject {
    @Published private(set) var metadata: VMMetadata?
    @Published private(set) var hostAdmission: AdmissionDecision
    @Published private(set) var creationAdmission: AdmissionDecision = .allowed
    @Published private(set) var configurationReadiness: VMConfigurationReadiness = .unavailable
    @Published private(set) var displayVirtualMachine: VZVirtualMachine?

    private let store: VMBundleStore
    private let admissionPolicy: AdmissionPolicy
    private let configurationBuilder: VMConfigurationBuilding
    private let lifecycleController: VMLifecycleControlling
    private let hostEnvironmentProvider: () -> HostEnvironment
    private let logger: Logger

    var canCreateVMOnHost: Bool {
        hostAdmission.isAllowed
    }

    var canCreateVM: Bool {
        canCreateVMOnHost && metadata == nil
    }

    var canStartVM: Bool {
        guard let metadata else {
            return false
        }
        return canCreateVMOnHost && configurationReadiness == .ready && VMStateMachine.canStart(from: metadata.state)
    }

    var canStopVM: Bool {
        guard let metadata else {
            return false
        }
        return VMStateMachine.canStop(from: metadata.state)
    }

    var canDeleteVM: Bool {
        guard let metadata else {
            return false
        }
        return !VMStateMachine.canStop(from: metadata.state)
    }

    init(
        store: VMBundleStore = VMBundleStore(),
        admissionPolicy: AdmissionPolicy = AdmissionPolicy(),
        configurationBuilder: VMConfigurationBuilding? = nil,
        lifecycleController: VMLifecycleControlling? = nil,
        hostEnvironmentProvider: @escaping () -> HostEnvironment = { HostEnvironment.current() },
        logger: Logger = Logger(subsystem: "pro.nanzhi.AIVM", category: "VMHome")
    ) {
        self.store = store
        self.admissionPolicy = admissionPolicy
        let resolvedConfigurationBuilder = configurationBuilder ?? VMConfigurationBuilder(store: store)
        self.configurationBuilder = resolvedConfigurationBuilder
        self.lifecycleController = lifecycleController ?? VMLifecycleController(
            store: store,
            configurationBuilder: resolvedConfigurationBuilder
        )
        self.hostEnvironmentProvider = hostEnvironmentProvider
        self.logger = logger
        self.hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        reload()
    }

    func reload() {
        metadata = try? store.loadCurrent()
        hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        displayVirtualMachine = lifecycleController.displayVirtualMachine
        refreshConfigurationReadiness()
    }

    func createVM(from installMediaURL: URL) {
        guard metadata == nil else {
            return
        }

        let isAccessingSecurityScopedResource = installMediaURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                installMediaURL.stopAccessingSecurityScopedResource()
            }
        }

        let host = hostEnvironmentProvider()
        hostAdmission = admissionPolicy.evaluateHost(host)
        let request = VMCreationRequest(
            displayName: displayName(for: installMediaURL),
            installMediaURL: installMediaURL,
            resources: .standard
        )
        let decision = admissionPolicy.evaluate(request: request, host: host)
        creationAdmission = decision
        guard decision.isAllowed else {
            refreshConfigurationReadiness()
            return
        }

        let now = Date()
        let createdMetadata = VMMetadata(
            displayName: request.displayName,
            installMediaPath: installMediaURL.path,
            bootSource: .installMedia,
            networkMode: .nat,
            state: .draft,
            resources: request.resources,
            createdAt: now,
            updatedAt: now
        )

        do {
            try store.createBundle(for: createdMetadata)
            metadata = createdMetadata
            logger.info("VM created id=\(createdMetadata.id.uuidString, privacy: .public) bootSource=\(createdMetadata.bootSource.rawValue, privacy: .public)")
        } catch {
            logger.error("VM create failed")
            reload()
            return
        }

        refreshConfigurationReadiness()
    }

    func startCurrentVM() async {
        guard let metadata, canStartVM else {
            return
        }

        do {
            self.metadata = try await lifecycleController.start(metadata: metadata)
            displayVirtualMachine = lifecycleController.displayVirtualMachine
        } catch {
            reload()
        }
    }

    func stopCurrentVM() async {
        guard let metadata, canStopVM else {
            return
        }

        do {
            self.metadata = try await lifecycleController.stop(metadata: metadata)
            displayVirtualMachine = lifecycleController.displayVirtualMachine
        } catch {
            reload()
        }
    }

    func deleteCurrentVM() {
        guard let metadata, canDeleteVM else {
            return
        }

        do {
            try store.deleteBundle(for: metadata.id)
            logger.info("VM deleted id=\(metadata.id.uuidString, privacy: .public)")
            self.metadata = nil
            creationAdmission = .allowed
            configurationReadiness = .unavailable
            displayVirtualMachine = nil
        } catch {
            logger.error("VM delete failed id=\(metadata.id.uuidString, privacy: .public)")
            reload()
        }
    }

    private func refreshConfigurationReadiness() {
        guard hostAdmission.isAllowed, let metadata else {
            configurationReadiness = .unavailable
            return
        }

        do {
            try configurationBuilder.build(for: metadata)
            configurationReadiness = .ready
        } catch {
            configurationReadiness = .failed
        }
    }

    private func displayName(for installMediaURL: URL) -> String {
        let baseName = installMediaURL.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return baseName.isEmpty ? "AIVM" : baseName
    }
}