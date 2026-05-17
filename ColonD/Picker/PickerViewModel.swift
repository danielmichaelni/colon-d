import Combine
import SwiftUI

@MainActor
final class PickerViewModel: ObservableObject {
    @Published var query = ""
    @Published var matches: [EmojiMatch] = []
    @Published var selectedIndex = 0

    var selectedMatch: EmojiMatch? {
        guard matches.indices.contains(selectedIndex) else { return nil }
        return matches[selectedIndex]
    }

    func update(query: String, matches: [EmojiMatch]) {
        let queryChanged = self.query != query
        self.query = query
        self.matches = matches
        selectedIndex = queryChanged ? 0 : min(selectedIndex, max(matches.count - 1, 0))
    }

    func selectNext() {
        guard !matches.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, matches.count - 1)
    }

    func selectPrevious() {
        guard !matches.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }
}
