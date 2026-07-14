import Foundation

struct Emoji: Identifiable, Equatable {
    let symbol: String
    let shortcode: String
    let tags: [String]

    var id: String { symbol }
}

struct EmojiMatch: Identifiable, Equatable {
    let emoji: Emoji
    let score: Int

    var id: String { emoji.id }
}
