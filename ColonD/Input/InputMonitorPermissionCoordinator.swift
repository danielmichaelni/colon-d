import Foundation

@MainActor
final class InputMonitorPermissionCoordinator {
    enum StartReadiness {
        case ready
        case waitingForPermissions
    }

    private let appState: AppState
    private let permissionStatus: PermissionStatusMonitor
    private var readinessWaitID: UUID?
    private var isSuspensionCallbackScheduled = false

    init(appState: AppState, permissionStatus: PermissionStatusMonitor) {
        self.appState = appState
        self.permissionStatus = permissionStatus
    }

    func prepareToStart(onReady: @escaping () -> Void) -> StartReadiness {
        if permissionStatus.isReady {
            stopWaiting()
            return .ready
        }

        permissionStatus.requestMissingPermissions()
        waitUntilReady(onReady: onReady)
        return .waitingForPermissions
    }

    func waitUntilReady(onReady: @escaping () -> Void) {
        guard !permissionStatus.isReady else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.appState.isEnabled else { return }
                onReady()
            }
            return
        }
        guard readinessWaitID == nil else { return }

        readinessWaitID = permissionStatus.waitUntilReady { [weak self] in
            guard let self else { return }
            self.readinessWaitID = nil
            guard self.appState.isEnabled else { return }
            onReady()
        }
    }

    func stopWaiting() {
        permissionStatus.cancelReadinessWait(readinessWaitID)
        readinessWaitID = nil
        isSuspensionCallbackScheduled = false
    }

    func suspendUntilReady(
        onSuspend: @escaping () -> Void,
        onReady: @escaping () -> Void
    ) {
        guard !isSuspensionCallbackScheduled else { return }
        isSuspensionCallbackScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            onSuspend()
            self.waitUntilReady(onReady: onReady)
            self.isSuspensionCallbackScheduled = false
        }
    }
}
