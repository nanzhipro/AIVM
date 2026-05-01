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
    private let hostEnvironmentProvider: () -> HostEnvironment

    var canCreateVMOnHost: Bool {
        hostAdmission.isAllowed
    }

    init(
        store: VMBundleStore = VMBundleStore(),
        admissionPolicy: AdmissionPolicy = AdmissionPolicy(),
        configurationBuilder: VMConfigurationBuilding? = nil,
        hostEnvironmentProvider: @escaping () -> HostEnvironment = { HostEnvironment.current() }
    ) {
        self.store = store
        self.admissionPolicy = admissionPolicy
        self.configurationBuilder = configurationBuilder ?? VMConfigurationBuilder(store: store)
        self.hostEnvironmentProvider = hostEnvironmentProvider
        self.hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        reload()
    }

    func reload() {
        metadata = try? store.loadCurrent()
        hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        refreshConfigurationReadiness()
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