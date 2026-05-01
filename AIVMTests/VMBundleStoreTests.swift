import XCTest
@testable import AIVM

final class VMBundleStoreTests: XCTestCase {
    func testMetadataRoundTripsThroughJSON() throws {
        let metadata = makeMetadata()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(VMMetadata.self, from: data)

        XCTAssertEqual(decoded, metadata)
        XCTAssertEqual(decoded.schemaVersion, VMMetadata.currentSchemaVersion)
        XCTAssertEqual(decoded.networkMode, .nat)
        XCTAssertEqual(decoded.bootSource, .installMedia)
    }

    func testBundleLayoutUsesStableNames() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let layout = VMBundleLayout(rootDirectory: URL(fileURLWithPath: "/tmp/AIVMTests", isDirectory: true))

        XCTAssertEqual(layout.bundleURL(for: id).lastPathComponent, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE.vmbundle")
        XCTAssertEqual(layout.configURL(for: id).lastPathComponent, "config.json")
        XCTAssertEqual(layout.diskImageURL(for: id).lastPathComponent, "Disk.img")
        XCTAssertEqual(layout.machineIdentifierURL(for: id).lastPathComponent, "MachineIdentifier")
        XCTAssertEqual(layout.nvramURL(for: id).lastPathComponent, "NVRAM")
        XCTAssertEqual(layout.logsURL(for: id).lastPathComponent, "logs")
    }

    func testCreateLoadListUpdateAndDeleteBundle() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = VMBundleStore(rootDirectory: root)
        var metadata = makeMetadata()

        let bundleURL = try store.createBundle(for: metadata)

        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.layout.configURL(for: metadata.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.layout.logsURL(for: metadata.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.layout.diskImageURL(for: metadata.id).path))

        XCTAssertEqual(try store.load(id: metadata.id), metadata)
        XCTAssertEqual(try store.loadAll(), [metadata])
        XCTAssertEqual(try store.loadCurrent(), metadata)

        metadata.state = .stopped
        metadata.bootSource = .disk
        metadata.updatedAt = metadata.updatedAt.addingTimeInterval(60)
        try store.save(metadata)

        XCTAssertEqual(try store.load(id: metadata.id).state, .stopped)
        XCTAssertEqual(try store.load(id: metadata.id).bootSource, .disk)

        try store.deleteBundle(for: metadata.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
    }

    func testUnsupportedSchemaIsRejected() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = VMBundleStore(rootDirectory: root)
        var metadata = makeMetadata()
        metadata.schemaVersion = 999

        try store.createBundle(for: metadata)

        XCTAssertThrowsError(try store.load(id: metadata.id)) { error in
            XCTAssertEqual(error as? VMBundleStoreError, .unsupportedSchema(999))
        }
    }

    func testStateLocalizationKeysCoverEveryState() {
        let expected: [VMState: LocalizationKey] = [
            .draft: .notInstalled,
            .installing: .installing,
            .stopped: .stopped,
            .running: .running,
            .error: .needsAttention
        ]

        XCTAssertEqual(Set(VMState.allCases), Set(expected.keys))
        for state in VMState.allCases {
            XCTAssertEqual(state.localizedKey, expected[state])
        }
    }

    private func makeTemporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AIVMTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makeMetadata() -> VMMetadata {
        VMMetadata(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            displayName: "Ubuntu",
            installMediaPath: "/tmp/ubuntu-arm64.iso",
            resources: .standard,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_030)
        )
    }
}