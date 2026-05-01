import Foundation

struct HostEnvironment {
    var architecture: String
    var macOSVersion: OperatingSystemVersion
    var cpuCoreCount: Int
    var memoryBytes: UInt64
    var availableDiskBytes: UInt64

    static func current() -> HostEnvironment {
        let processInfo = ProcessInfo.processInfo

        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "unsupported"
        #endif

        return HostEnvironment(
            architecture: architecture,
            macOSVersion: processInfo.operatingSystemVersion,
            cpuCoreCount: processInfo.processorCount,
            memoryBytes: processInfo.physicalMemory,
            availableDiskBytes: availableCapacity(at: VMBundleStore.defaultRootDirectory())
        )
    }

    private static func availableCapacity(at url: URL) -> UInt64 {
        let probeURL = url.deletingLastPathComponent()
        let capacity = try? probeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        return UInt64(max(capacity ?? 0, 0))
    }
}

struct VMCreationRequest: Equatable {
    var displayName: String
    var installMediaURL: URL
    var resources: VMResourceConfiguration
}

enum ISOArchitecture: String, Equatable {
    case arm64
    case x86_64
    case unknown
}

enum ISOCompatibility: Equatable {
    case primaryUbuntuARM64
    case supplementalFedoraARM64
    case unknown
}

enum AdmissionIssueSeverity: String, Equatable {
    case blocker
    case warning
}

enum AdmissionIssueCode: String, CaseIterable, Equatable {
    case unsupportedHostArchitecture
    case unsupportedMacOSVersion
    case missingISO
    case unreadableISO
    case invalidISOExtension
    case isoArchitectureMismatch
    case unknownDistribution
    case cpuTooLow
    case cpuTooHigh
    case memoryTooLow
    case memoryTooHigh
    case diskTooLow
    case insufficientDiskSpace
}

struct AdmissionIssue: Equatable {
    var code: AdmissionIssueCode
    var severity: AdmissionIssueSeverity
    var recoveryKey: LocalizationKey?
}

struct AdmissionDecision: Equatable {
    var issues: [AdmissionIssue]

    static let allowed = AdmissionDecision(issues: [])

    var blockers: [AdmissionIssue] {
        issues.filter { $0.severity == .blocker }
    }

    var warnings: [AdmissionIssue] {
        issues.filter { $0.severity == .warning }
    }

    var isAllowed: Bool {
        blockers.isEmpty
    }

    func contains(_ code: AdmissionIssueCode) -> Bool {
        issues.contains { $0.code == code }
    }
}

final class AdmissionPolicy {
    static let minimumCPUCount = 2
    static let minimumMemoryBytes: UInt64 = 4 * 1024 * 1024 * 1024
    static let minimumDiskBytes: UInt64 = 32 * 1024 * 1024 * 1024
    static let diskSafetyBufferBytes: UInt64 = 8 * 1024 * 1024 * 1024
    static let minimumMacOSMajorVersion = 14

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func evaluateHost(_ host: HostEnvironment) -> AdmissionDecision {
        AdmissionDecision(issues: hostIssues(for: host))
    }

    func evaluate(request: VMCreationRequest, host: HostEnvironment) -> AdmissionDecision {
        var issues = hostIssues(for: host)
        issues.append(contentsOf: isoIssues(for: request.installMediaURL, host: host))
        issues.append(contentsOf: resourceIssues(for: request.resources, host: host))
        return AdmissionDecision(issues: issues)
    }

    func architecture(for isoURL: URL) -> ISOArchitecture {
        let name = isoURL.lastPathComponent.lowercased()
        if name.contains("arm64") || name.contains("aarch64") {
            return .arm64
        }
        if name.contains("amd64") || name.contains("x86_64") || name.contains("x64") {
            return .x86_64
        }
        return .unknown
    }

    func compatibility(for isoURL: URL) -> ISOCompatibility {
        let name = isoURL.lastPathComponent.lowercased()
        guard architecture(for: isoURL) == .arm64 else {
            return .unknown
        }
        if name.contains("ubuntu") && name.contains("desktop") {
            return .primaryUbuntuARM64
        }
        if name.contains("fedora") && name.contains("workstation") {
            return .supplementalFedoraARM64
        }
        return .unknown
    }

    private func hostIssues(for host: HostEnvironment) -> [AdmissionIssue] {
        var issues: [AdmissionIssue] = []
        if host.architecture != "arm64" {
            issues.append(blocker(.unsupportedHostArchitecture, recoveryKey: .configInvalid))
        }
        if host.macOSVersion.majorVersion < Self.minimumMacOSMajorVersion {
            issues.append(blocker(.unsupportedMacOSVersion, recoveryKey: .configInvalid))
        }
        return issues
    }

    private func isoIssues(for isoURL: URL, host: HostEnvironment) -> [AdmissionIssue] {
        var issues: [AdmissionIssue] = []
        let path = isoURL.path

        guard fileManager.fileExists(atPath: path) else {
            return [blocker(.missingISO, recoveryKey: .chooseAnotherISO)]
        }

        if !fileManager.isReadableFile(atPath: path) {
            issues.append(blocker(.unreadableISO, recoveryKey: .chooseAnotherISO))
        }

        if isoURL.pathExtension.lowercased() != "iso" {
            issues.append(blocker(.invalidISOExtension, recoveryKey: .chooseAnotherISO))
        }

        let isoArchitecture = architecture(for: isoURL)
        if host.architecture == "arm64", isoArchitecture == .x86_64 {
            issues.append(blocker(.isoArchitectureMismatch, recoveryKey: .chooseAnotherISO))
        }

        if compatibility(for: isoURL) == .unknown, !issues.contains(where: { $0.code == .isoArchitectureMismatch }) {
            issues.append(warning(.unknownDistribution, recoveryKey: nil))
        }

        return issues
    }

    private func resourceIssues(for resources: VMResourceConfiguration, host: HostEnvironment) -> [AdmissionIssue] {
        var issues: [AdmissionIssue] = []

        if resources.cpuCount < Self.minimumCPUCount {
            issues.append(blocker(.cpuTooLow, recoveryKey: .editSettings))
        }

        if resources.cpuCount > maxCPUCount(for: host) {
            issues.append(blocker(.cpuTooHigh, recoveryKey: .editSettings))
        }

        if resources.memoryBytes < Self.minimumMemoryBytes {
            issues.append(blocker(.memoryTooLow, recoveryKey: .editSettings))
        }

        if resources.memoryBytes > maxMemoryBytes(for: host) {
            issues.append(blocker(.memoryTooHigh, recoveryKey: .editSettings))
        }

        if resources.diskBytes < Self.minimumDiskBytes {
            issues.append(blocker(.diskTooLow, recoveryKey: .editSettings))
        }

        if host.availableDiskBytes < resources.diskBytes + Self.diskSafetyBufferBytes {
            issues.append(blocker(.insufficientDiskSpace, recoveryKey: .freeSpaceRetry))
        }

        return issues
    }

    private func maxCPUCount(for host: HostEnvironment) -> Int {
        max(Self.minimumCPUCount, host.cpuCoreCount - 1)
    }

    private func maxMemoryBytes(for host: HostEnvironment) -> UInt64 {
        max(Self.minimumMemoryBytes, host.memoryBytes * 3 / 4)
    }

    private func blocker(_ code: AdmissionIssueCode, recoveryKey: LocalizationKey?) -> AdmissionIssue {
        AdmissionIssue(code: code, severity: .blocker, recoveryKey: recoveryKey)
    }

    private func warning(_ code: AdmissionIssueCode, recoveryKey: LocalizationKey?) -> AdmissionIssue {
        AdmissionIssue(code: code, severity: .warning, recoveryKey: recoveryKey)
    }
}