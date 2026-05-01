import Foundation
import Combine

@MainActor
final class VMHomeViewModel: ObservableObject {
    @Published private(set) var metadata: VMMetadata?
    @Published private(set) var hostAdmission: AdmissionDecision
    @Published private(set) var configurationReadiness: VMConfigurationReadiness = .unavailable

    private let store: VMBundleStore
    private let admissionPolicy: AdmissionPolicy
    private let configurationBuilder: VMConfigurationBuilding
    private let lifecycleController: VMLifecycleControlling
    private let hostEnvironmentProvider: () -> HostEnvironment

    var canCreateVMOnHost: Bool {
        hostAdmission.isAllowed
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

    init(
        store: VMBundleStore = VMBundleStore(),
        admissionPolicy: AdmissionPolicy = AdmissionPolicy(),
        configurationBuilder: VMConfigurationBuilding? = nil,
        lifecycleController: VMLifecycleControlling? = nil,
        hostEnvironmentProvider: @escaping () -> HostEnvironment = { HostEnvironment.current() }
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
        self.hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        reload()
    }

    func reload() {
        metadata = try? store.loadCurrent()
        hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        refreshConfigurationReadiness()
    }

    func startCurrentVM() async {
        guard let metadata, canStartVM else {
            return
        }

        do {
            self.metadata = try await lifecycleController.start(metadata: metadata)
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
        } catch {
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
}