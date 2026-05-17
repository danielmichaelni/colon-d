import AppKit

@MainActor
final class InputEventTaps {
    private let onTrackingKey: (KeyInfo) -> Bool
    private let onControlKey: (KeyInfo) -> Bool

    private lazy var trackingEventTap = GlobalKeyEventTap(
        options: .listenOnly,
        onKeyDown: { [weak self] keyInfo in
            self?.onTrackingKey(keyInfo) ?? true
        }
    )
    private lazy var controlEventTap = GlobalKeyEventTap(
        options: .defaultTap,
        onKeyDown: { [weak self] keyInfo in
            self?.onControlKey(keyInfo) ?? true
        }
    )

    init(
        onTrackingKey: @escaping (KeyInfo) -> Bool,
        onControlKey: @escaping (KeyInfo) -> Bool
    ) {
        self.onTrackingKey = onTrackingKey
        self.onControlKey = onControlKey
    }

    var isTracking: Bool {
        trackingEventTap.isRunning
    }

    func startTracking() throws {
        try trackingEventTap.start()
    }

    func stopTracking() {
        trackingEventTap.stop()
    }

    func startControl() -> Bool {
        guard !controlEventTap.isRunning else { return true }

        do {
            try controlEventTap.start()
            return true
        } catch {
            return false
        }
    }

    func stopControl() {
        controlEventTap.stop()
    }
}
