import Foundation
import Combine

@MainActor
final class VMHomeViewModel: ObservableObject {
    @Published private(set) var metadata: VMMetadata?

    private let store: VMBundleStore

    init(store: VMBundleStore = VMBundleStore()) {
        self.store = store
        reload()
    }

    func reload() {
        metadata = try? store.loadCurrent()
    }
}