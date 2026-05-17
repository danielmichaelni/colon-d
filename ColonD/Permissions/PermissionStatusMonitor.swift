import Foundation

@MainActor
final class PermissionStatusMonitor {
    struct Snapshot: Equatable {
        let isReady: Bool
        let needsAccessibility: Bool
        let needsInputMonitoring: Bool

        init(permissions: PermissionGate) {
            isReady = permissions.isReady
            needsAccessibility = permissions.needsAccessibility
            needsInputMonitoring = permissions.needsInputMonitoring
        }
    }

    let permissions: PermissionGate

    private var timer: Timer?
    private var lastSnapshot: Snapshot
    private var listeners: [UUID: (Snapshot) -> Void] = [:]
    private var readinessWaiters: [UUID: () -> Void] = [:]

    init(permissions: PermissionGate) {
        self.permissions = permissions
        lastSnapshot = Snapshot(permissions: permissions)
    }

    var snapshot: Snapshot {
        Snapshot(permissions: permissions)
    }

    var isReady: Bool {
        snapshot.isReady
    }

    func requestMissingPermissions() {
        permissions.requestMissingPermissions()
        refresh()
    }

    @discardableResult
    func refresh() -> Bool {
        let didChange = updateSnapshot()
        startPollingIfNeeded()
        return didChange
    }

    @discardableResult
    func addListener(_ listener: @escaping (Snapshot) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        listener(snapshot)
        startPollingIfNeeded()
        return id
    }

    func removeListener(_ id: UUID?) {
        guard let id else { return }
        listeners[id] = nil
        stopPollingIfIdle()
    }

    @discardableResult
    func waitUntilReady(_ onReady: @escaping () -> Void) -> UUID? {
        guard !snapshot.isReady else {
            onReady()
            return nil
        }

        let id = UUID()
        readinessWaiters[id] = onReady
        startPollingIfNeeded()
        return id
    }

    func cancelReadinessWait(_ id: UUID?) {
        guard let id else { return }
        readinessWaiters[id] = nil
        stopPollingIfIdle()
    }

    private func startPollingIfNeeded() {
        guard timer == nil, !snapshot.isReady || !readinessWaiters.isEmpty else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSnapshot()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @discardableResult
    private func updateSnapshot() -> Bool {
        let currentSnapshot = snapshot
        let didChange = currentSnapshot != lastSnapshot
        if didChange {
            lastSnapshot = currentSnapshot
            listeners.values.forEach { $0(currentSnapshot) }
        }

        if currentSnapshot.isReady {
            let waiters = readinessWaiters.values
            readinessWaiters.removeAll()
            waiters.forEach { $0() }
        }

        stopPollingIfIdle()
        return didChange
    }

    private func stopPollingIfIdle() {
        guard readinessWaiters.isEmpty, snapshot.isReady else { return }

        timer?.invalidate()
        timer = nil
    }
}
