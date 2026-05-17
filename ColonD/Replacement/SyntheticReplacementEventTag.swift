import CoreGraphics

// Marks replacement keystrokes so the global event tap does not treat them as user input.
enum SyntheticReplacementEventTag {
    private nonisolated static let userData: Int64 = 0x434F_4C4F_4E44

    nonisolated static func isTagged(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == userData
    }

    nonisolated static func tag(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: userData)
    }
}
