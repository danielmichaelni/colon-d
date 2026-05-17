import Foundation

struct PermissionGate {
    let accessibility: AccessibilityPermissionController
    let inputMonitoring: InputMonitoringPermissionController

    init(
        accessibility: AccessibilityPermissionController = AccessibilityPermissionController(),
        inputMonitoring: InputMonitoringPermissionController = InputMonitoringPermissionController()
    ) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }

    var isReady: Bool {
        accessibility.isTrusted && inputMonitoring.isTrusted
    }

    var needsAccessibility: Bool {
        !accessibility.isTrusted
    }

    var needsInputMonitoring: Bool {
        !inputMonitoring.isTrusted
    }

    func requestMissingPermissions() {
        accessibility.requestIfNeeded()
        inputMonitoring.requestIfNeeded()
    }
}
