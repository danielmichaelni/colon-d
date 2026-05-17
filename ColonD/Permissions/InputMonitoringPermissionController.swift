import AppKit

struct InputMonitoringPermissionController {
    var isTrusted: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    func requestIfNeeded() -> Bool {
        guard !isTrusted else { return true }
        return CGRequestListenEventAccess()
    }

    func openSettings() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            )
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
