import XCTest
@testable import AIVM

final class AdmissionPolicyTests: XCTestCase {
    private let policy = AdmissionPolicy()
    private var temporaryRoots: [URL] = []

    override func tearDown() {
        for root in temporaryRoots {
            try? FileManager.default.removeItem(at: root)
        }
        temporaryRoots.removeAll()
        super.tearDown()
    }

    func testSupportedUbuntuARM64RequestIsAllowed() throws {
        let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
        let decision = policy.evaluate(request: makeRequest(isoURL: isoURL), host: supportedHost())

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.blockers.isEmpty)
        XCTAssertTrue(decision.warnings.isEmpty)
    }

    func testUnsupportedHostArchitectureBlocksHostOnlyAdmission() {
        let host = supportedHost(architecture: "x86_64")
        let decision = policy.evaluateHost(host)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.contains(.unsupportedHostArchitecture))
    }

    func testOlderMacOSBlocksHostOnlyAdmission() {
        let host = supportedHost(macOSVersion: OperatingSystemVersion(majorVersion: 13, minorVersion: 6, patchVersion: 0))
        let decision = policy.evaluateHost(host)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.contains(.unsupportedMacOSVersion))
    }

    func testAMD64ISOBlocksOnAppleSilicon() throws {
        let isoURL = try makeISO(named: "ubuntu-24.04-desktop-amd64.iso")
        let decision = policy.evaluate(request: makeRequest(isoURL: isoURL), host: supportedHost())

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.contains(.isoArchitectureMismatch))
    }

    func testUnknownARM64DistributionWarnsButAllows() throws {
        let isoURL = try makeISO(named: "debian-testing-arm64.iso")
        let decision = policy.evaluate(request: makeRequest(isoURL: isoURL), host: supportedHost())

        XCTAssertTrue(decision.isAllowed)
        XCTAssertEqual(decision.warnings.map(\.code), [.unknownDistribution])
    }

    func testLowResourcesAreBlocked() throws {
        let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
        let resources = VMResourceConfiguration(cpuCount: 1, memoryBytes: 2 * gib, diskBytes: 16 * gib)
        let decision = policy.evaluate(request: makeRequest(isoURL: isoURL, resources: resources), host: supportedHost())

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.contains(.cpuTooLow))
        XCTAssertTrue(decision.contains(.memoryTooLow))
        XCTAssertTrue(decision.contains(.diskTooLow))
    }

    func testInsufficientDiskSpaceBlocks() throws {
        let isoURL = try makeISO(named: "ubuntu-24.04-desktop-arm64.iso")
        let host = supportedHost(availableDiskBytes: 36 * gib)
        let decision = policy.evaluate(request: makeRequest(isoURL: isoURL), host: host)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.contains(.insufficientDiskSpace))
    }

    @MainActor
    func testRootViewModelReflectsHostOnlyAdmission() {
        let root = makeTemporaryRoot()
        let store = VMBundleStore(rootDirectory: root)
        let viewModel = VMHomeViewModel(
            store: store,
            admissionPolicy: policy,
            hostEnvironmentProvider: { self.supportedHost(architecture: "x86_64") }
        )

        XCTAssertFalse(viewModel.canCreateVMOnHost)
        XCTAssertTrue(viewModel.hostAdmission.contains(.unsupportedHostArchitecture))
    }

    private var gib: UInt64 { 1024 * 1024 * 1024 }

    private func supportedHost(
        architecture: String = "arm64",
        macOSVersion: OperatingSystemVersion = OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0),
        cpuCoreCount: Int = 8,
        memoryBytes: UInt64 = 16 * 1024 * 1024 * 1024,
        availableDiskBytes: UInt64 = 256 * 1024 * 1024 * 1024
    ) -> HostEnvironment {
        HostEnvironment(
            architecture: architecture,
            macOSVersion: macOSVersion,
            cpuCoreCount: cpuCoreCount,
            memoryBytes: memoryBytes,
            availableDiskBytes: availableDiskBytes
        )
    }

    private func makeRequest(
        isoURL: URL,
        resources: VMResourceConfiguration = .standard
    ) -> VMCreationRequest {
        VMCreationRequest(displayName: "Ubuntu", installMediaURL: isoURL, resources: resources)
    }

    private func makeISO(named name: String) throws -> URL {
        let root = makeTemporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name, isDirectory: false)
        try Data("AIVM test ISO".utf8).write(to: url)
        return url
    }

    private func makeTemporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIVMAdmissionTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryRoots.append(root)
        return root
    }
}