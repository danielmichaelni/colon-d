import Foundation

@MainActor
final class EmojiUsageHistory {
    private let defaults: UserDefaults
    private let key: String
    private let capacity: Int
    private let validEmojiIDs: Set<String>

    private(set) var recentEmojiIDs: [String]

    init(
        defaults: UserDefaults = .standard,
        validEmojiIDs: Set<String>,
        capacity: Int = 100,
        key: String = "ColonD.recentEmojiIDs"
    ) {
        precondition(capacity > 0)

        self.defaults = defaults
        self.key = key
        self.capacity = capacity
        self.validEmojiIDs = validEmojiIDs

        let persistedIDs = defaults.stringArray(forKey: key) ?? []
        recentEmojiIDs = Self.sanitized(
            persistedIDs,
            validEmojiIDs: validEmojiIDs,
            capacity: capacity
        )

        if recentEmojiIDs != persistedIDs {
            defaults.set(recentEmojiIDs, forKey: key)
        }
    }

    func record(_ emoji: Emoji) {
        guard validEmojiIDs.contains(emoji.id) else { return }

        recentEmojiIDs.removeAll { $0 == emoji.id }
        recentEmojiIDs.insert(emoji.id, at: 0)
        if recentEmojiIDs.count > capacity {
            recentEmojiIDs.removeLast(recentEmojiIDs.count - capacity)
        }

        defaults.set(recentEmojiIDs, forKey: key)
    }

    private static func sanitized(
        _ emojiIDs: [String],
        validEmojiIDs: Set<String>,
        capacity: Int
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for emojiID in emojiIDs {
            guard validEmojiIDs.contains(emojiID), seen.insert(emojiID).inserted else {
                continue
            }

            result.append(emojiID)
            if result.count == capacity {
                break
            }
        }

        return result
    }
}
