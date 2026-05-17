import Foundation

struct EmojiIndex {
    private let emojis: [Emoji]

    init(emojis: [Emoji]) {
        self.emojis = emojis
    }

    func search(_ query: String, limit: Int = 20) -> [EmojiMatch] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return Array(emojis.prefix(limit)).map { EmojiMatch(emoji: $0, score: 0) }
        }

        return emojis.compactMap { emoji in
            let bestScore =
                emoji.searchableTerms
                .map { score(query: normalizedQuery, candidate: normalize($0)) }
                .max() ?? 0

            guard bestScore > 0 else { return nil }
            return EmojiMatch(emoji: emoji, score: bestScore)
        }
        .sorted {
            if $0.score == $1.score {
                return $0.emoji.shortcode < $1.emoji.shortcode
            }
            return $0.score > $1.score
        }
        .prefix(limit)
        .map { $0 }
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func score(query: String, candidate: String) -> Int {
        guard !query.isEmpty, !candidate.isEmpty else { return 0 }

        if candidate == query { return 10_000 - candidate.count }
        if candidate.hasPrefix(query) { return 8_000 - candidate.count }
        if candidate.contains(query) { return 6_000 - candidate.count }

        var score = 0
        var queryIndex = query.startIndex
        var lastMatchIndex: String.Index?

        for candidateIndex in candidate.indices {
            guard queryIndex < query.endIndex else { break }
            guard candidate[candidateIndex] == query[queryIndex] else { continue }

            score += 500
            if let lastMatchIndex,
                candidate.index(after: lastMatchIndex) == candidateIndex
            {
                score += 150
            }
            if candidateIndex == candidate.startIndex {
                score += 100
            }

            lastMatchIndex = candidateIndex
            query.formIndex(after: &queryIndex)
        }

        guard queryIndex == query.endIndex else { return 0 }
        return score - candidate.count
    }
}
