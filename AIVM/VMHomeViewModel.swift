import Foundation
import Combine

@MainActor
final class VMHomeViewModel: ObservableObject {
    @Published private(set) var metadata: VMMetadata?
    @Published private(set) var hostAdmission: AdmissionDecision

    private let store: VMBundleStore
    private let admissionPolicy: AdmissionPolicy
    private let hostEnvironmentProvider: () -> HostEnvironment

    var canCreateVMOnHost: Bool {
        hostAdmission.isAllowed
    }

    init(
        store: VMBundleStore = VMBundleStore(),
        admissionPolicy: AdmissionPolicy = AdmissionPolicy(),
        hostEnvironmentProvider: @escaping () -> HostEnvironment = { HostEnvironment.current() }
    ) {
        self.store = store
        self.admissionPolicy = admissionPolicy
        self.hostEnvironmentProvider = hostEnvironmentProvider
        self.hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
        reload()
    }

    func reload() {
        metadata = try? store.loadCurrent()
        hostAdmission = admissionPolicy.evaluateHost(hostEnvironmentProvider())
    }
}