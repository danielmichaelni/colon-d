import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    private static let enabledKey = "ColonD.isEnabled"

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }
}
