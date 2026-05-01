import Foundation

struct VMBundleLayout: Equatable {
    static let bundleExtension = "vmbundle"
    static let diskImageFileName = "Disk.img"
    static let machineIdentifierFileName = "MachineIdentifier"
    static let nvramFileName = "NVRAM"
    static let configFileName = "config.json"
    static let logsDirectoryName = "logs"

    let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory.standardizedFileURL
    }

    func bundleURL(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(id.uuidString).\(Self.bundleExtension)", isDirectory: true)
    }

    func configURL(for id: UUID) -> URL {
        bundleURL(for: id).appendingPathComponent(Self.configFileName, isDirectory: false)
    }

    func diskImageURL(for id: UUID) -> URL {
        bundleURL(for: id).appendingPathComponent(Self.diskImageFileName, isDirectory: false)
    }

    func machineIdentifierURL(for id: UUID) -> URL {
        bundleURL(for: id).appendingPathComponent(Self.machineIdentifierFileName, isDirectory: false)
    }

    func nvramURL(for id: UUID) -> URL {
        bundleURL(for: id).appendingPathComponent(Self.nvramFileName, isDirectory: false)
    }

    func logsURL(for id: UUID) -> URL {
        bundleURL(for: id).appendingPathComponent(Self.logsDirectoryName, isDirectory: true)
    }

    func contains(_ url: URL) -> Bool {
        let rootPath = rootDirectory.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}

enum VMBundleStoreError: Error, Equatable {
    case unsafeBundlePath(URL)
    case missingConfig(UUID)
    case unsupportedSchema(Int)
}

final class VMBundleStore {
    let layout: VMBundleLayout
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootDirectory: URL = VMBundleStore.defaultRootDirectory(), fileManager: FileManager = .default) {
        self.layout = VMBundleLayout(rootDirectory: rootDirectory)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    static func defaultRootDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("phas", isDirectory: true)
            .appendingPathComponent("VMs", isDirectory: true)
    }

    @discardableResult
    func createBundle(for metadata: VMMetadata) throws -> URL {
        let bundleURL = layout.bundleURL(for: metadata.id)
        try validateBundleURL(bundleURL)
        try fileManager.createDirectory(at: layout.rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.logsURL(for: metadata.id), withIntermediateDirectories: true)
        try save(metadata)
        return bundleURL
    }

    func save(_ metadata: VMMetadata) throws {
        let bundleURL = layout.bundleURL(for: metadata.id)
        try validateBundleURL(bundleURL)
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.logsURL(for: metadata.id), withIntermediateDirectories: true)
        let data = try encoder.encode(metadata)
        try data.write(to: layout.configURL(for: metadata.id), options: .atomic)
    }

    func load(id: UUID) throws -> VMMetadata {
        let configURL = layout.configURL(for: id)
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw VMBundleStoreError.missingConfig(id)
        }

        let metadata = try decoder.decode(VMMetadata.self, from: Data(contentsOf: configURL))
        try validate(metadata)
        return metadata
    }

    func loadAll() throws -> [VMMetadata] {
        guard fileManager.fileExists(atPath: layout.rootDirectory.path) else {
            return []
        }

        let bundleURLs = try fileManager.contentsOfDirectory(
            at: layout.rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try bundleURLs
            .filter { $0.pathExtension == VMBundleLayout.bundleExtension }
            .map { bundleURL in
                let rawID = bundleURL.deletingPathExtension().lastPathComponent
                guard let id = UUID(uuidString: rawID) else {
                    throw VMBundleStoreError.unsafeBundlePath(bundleURL)
                }
                return try load(id: id)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func loadCurrent() throws -> VMMetadata? {
        try loadAll().first
    }

    func deleteBundle(for id: UUID) throws {
        let bundleURL = layout.bundleURL(for: id)
        try validateBundleURL(bundleURL)
        guard fileManager.fileExists(atPath: bundleURL.path) else {
            return
        }
        try fileManager.removeItem(at: bundleURL)
    }

    private func validate(_ metadata: VMMetadata) throws {
        guard metadata.schemaVersion == VMMetadata.currentSchemaVersion else {
            throw VMBundleStoreError.unsupportedSchema(metadata.schemaVersion)
        }
    }

    private func validateBundleURL(_ bundleURL: URL) throws {
        guard layout.contains(bundleURL), bundleURL.pathExtension == VMBundleLayout.bundleExtension else {
            throw VMBundleStoreError.unsafeBundlePath(bundleURL)
        }
    }
}