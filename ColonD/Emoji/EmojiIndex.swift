import Foundation

struct EmojiIndex {
    private let emojis: [Emoji]

    init(emojis: [Emoji]) {
        self.emojis = emojis
    }

    func search(
        _ query: String,
        recentEmojiIDs: [String] = [],
        limit: Int = 20
    ) -> [EmojiMatch] {
        guard limit > 0 else { return [] }

        let normalizedQuery = normalize(query)
        let recencyRanks = recencyRanks(for: recentEmojiIDs)

        guard !normalizedQuery.isEmpty else {
            return emojis.enumerated()
                .sorted { lhs, rhs in
                    let lhsRank = recencyRanks[lhs.element.id]
                    let rhsRank = recencyRanks[rhs.element.id]

                    switch (lhsRank, rhsRank) {
                    case let (lhsRank?, rhsRank?) where lhsRank != rhsRank:
                        return lhsRank < rhsRank
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    default:
                        return lhs.offset < rhs.offset
                    }
                }
                .prefix(limit)
                .map { EmojiMatch(emoji: $0.element, score: 0) }
        }

        return emojis.enumerated().compactMap { databaseIndex, emoji in
            let matches = [
                rankedMatch(
                    query: normalizedQuery,
                    candidate: normalize(emoji.shortcode),
                    source: .shortcode
                )
            ] + emoji.tags.map {
                rankedMatch(
                    query: normalizedQuery,
                    candidate: normalize($0),
                    source: .tag
                )
            }
            guard let bestMatch = matches.compactMap({ $0 }).max(by: isLowerQuality) else {
                return nil
            }

            return SearchResult(
                match: EmojiMatch(emoji: emoji, score: bestMatch.score),
                quality: bestMatch.quality,
                recencyRank: recencyRanks[emoji.id],
                databaseIndex: databaseIndex
            )
        }
        .sorted(by: ranksBefore)
        .prefix(limit)
        .map(\.match)
    }

    private func rankedMatch(
        query: String,
        candidate: String,
        source: MatchSource
    ) -> RankedMatch? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }

        let kind: MatchKind
        let matchScore: Int

        if candidate == query {
            kind = .exact
            matchScore = 10_000 - candidate.count
        } else if candidate.hasPrefix(query) {
            kind = .prefix
            matchScore = 8_000 - candidate.count
        } else if candidate.contains(query) {
            kind = .contains
            matchScore = 6_000 - candidate.count
        } else {
            matchScore = fuzzyScore(
                query: query,
                candidate: candidate
            )
            guard matchScore > 0 else { return nil }
            kind = .fuzzy
        }

        return RankedMatch(
            quality: MatchQuality(kind: kind, source: source),
            score: matchScore
        )
    }

    private func isLowerQuality(_ lhs: RankedMatch, _ rhs: RankedMatch) -> Bool {
        if lhs.quality != rhs.quality {
            return lhs.quality < rhs.quality
        }
        return lhs.score < rhs.score
    }

    private func ranksBefore(_ lhs: SearchResult, _ rhs: SearchResult) -> Bool {
        if lhs.quality.kind != rhs.quality.kind {
            return lhs.quality.kind > rhs.quality.kind
        }

        switch (lhs.recencyRank, rhs.recencyRank) {
        case let (lhsRank?, rhsRank?) where lhsRank != rhsRank:
            return lhsRank < rhsRank
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }

        if lhs.quality.source != rhs.quality.source {
            return lhs.quality.source > rhs.quality.source
        }

        if lhs.match.score != rhs.match.score {
            return lhs.match.score > rhs.match.score
        }
        if lhs.match.emoji.shortcode != rhs.match.emoji.shortcode {
            return lhs.match.emoji.shortcode < rhs.match.emoji.shortcode
        }
        return lhs.databaseIndex < rhs.databaseIndex
    }

    private func recencyRanks(for emojiIDs: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (index, emojiID) in emojiIDs.enumerated() where result[emojiID] == nil {
            result[emojiID] = index
        }
        return result
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func fuzzyScore(query: String, candidate: String) -> Int {
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

private enum MatchKind: Int, Comparable {
    case fuzzy
    case contains
    case prefix
    case exact

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum MatchSource: Int, Comparable {
    case tag
    case shortcode

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct MatchQuality: Comparable {
    let kind: MatchKind
    let source: MatchSource

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.kind != rhs.kind {
            return lhs.kind < rhs.kind
        }
        return lhs.source < rhs.source
    }
}

private struct RankedMatch {
    let quality: MatchQuality
    let score: Int
}

private struct SearchResult {
    let match: EmojiMatch
    let quality: MatchQuality
    let recencyRank: Int?
    let databaseIndex: Int
}
