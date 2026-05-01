import Foundation

enum LocalizationKey: String, CaseIterable {
    case appTitle = "app.title"
    case supportedGuest = "label.supportedGuest"
    case emptyTitle = "home.empty.title"
    case emptySubtitle = "home.empty.subtitle"
    case createVM = "action.createVM"
    case selectISO = "action.selectISO"
    case notInstalled = "status.notInstalled"
    case installing = "status.installing"
    case stopped = "status.stopped"
    case running = "status.running"
    case needsAttention = "status.needsAttention"
    case isoMissing = "error.isoMissing.title"
    case storageLow = "error.storageLow.title"
    case configInvalid = "error.configInvalid.title"
    case startFailed = "error.startFailed.title"
    case chooseAnotherISO = "action.chooseAnotherISO"
    case freeSpaceRetry = "action.freeSpaceRetry"
    case editSettings = "action.editSettings"
    case retryStart = "action.retryStart"
    case viewLogs = "action.viewLogs"
    case deleteVM = "action.deleteVM"
}

final class AppBundleMarker: NSObject {}
