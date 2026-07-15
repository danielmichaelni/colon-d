import AppKit
import Carbon
import Testing

@testable import ColonD

@Suite("Picker control keys")
@MainActor
struct PickerControlKeyTests {
    private func makeSession() -> PickerSessionController {
        let viewModel = PickerViewModel()
        let suiteName = "ColonDTests.PickerControlKeyTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PickerSessionController(
            emojiIndex: EmojiIndex(emojis: []),
            emojiUsageHistory: EmojiUsageHistory(
                defaults: defaults,
                validEmojiIDs: []
            ),
            viewModel: viewModel,
            windowController: PickerWindowController(viewModel: viewModel)
        )
    }

    @Test("Unmodified picker controls are recognized")
    func recognizesUnmodifiedControls() {
        let session = makeSession()

        #expect(
            session.isControlKey(
                KeyInfo(keyCode: CGKeyCode(kVK_Tab), characters: "\t")
            )
        )
        #expect(
            session.isControlKey(
                KeyInfo(keyCode: CGKeyCode(kVK_DownArrow), characters: nil)
            )
        )
    }

    @Test(
        "Modified navigation shortcuts are forwarded",
        arguments: [
            CGEventFlags.maskCommand,
            .maskControl,
            .maskAlternate,
            .maskShift,
        ]
    )
    func rejectsModifiedControls(modifier: CGEventFlags) {
        let session = makeSession()
        let commandTab = KeyInfo(
            keyCode: CGKeyCode(kVK_Tab),
            characters: "\t",
            flags: modifier
        )
        let modifiedArrow = KeyInfo(
            keyCode: CGKeyCode(kVK_DownArrow),
            characters: nil,
            flags: modifier
        )

        #expect(!session.isControlKey(commandTab))
        #expect(!session.isControlKey(modifiedArrow))
    }
}

@Suite("Input session")
struct InputSessionStateMachineTests {
    @Test("Tracks a shortcode after a boundary")
    func tracksShortcode() {
        var session = InputSessionStateMachine()

        #expect(session.handleCharacter(":", isAtStartOfText: true) == .updatePicker(query: ""))
        #expect(session.handleCharacter("s", isAtStartOfText: false) == .updatePicker(query: "s"))
        #expect(session.handleCharacter("m", isAtStartOfText: false) == .updatePicker(query: "sm"))
        #expect(session.trackedTriggerText == ":sm")
    }

    @Test("Does not trigger after a non-boundary character")
    func rejectsEmbeddedColon() {
        var session = InputSessionStateMachine()

        #expect(session.handleCharacter("a", isAtStartOfText: false) == .none)
        guard case .reconcileFocusedText(let request) = session.handleCharacter(
            ":",
            isAtStartOfText: false
        ) else {
            Issue.record("Expected focused-text reconciliation")
            return
        }

        #expect(request.reconciliation == .recoverTriggerSuffix)
        #expect(session.reconcile(textBeforeCaret: "a:", reconciliation: request.reconciliation) == .none)
    }
}

@Suite("Emoji search")
struct EmojiIndexTests {
    @Test("Exact shortcode matches outrank tag matches")
    func exactShortcodeWins() {
        let exact = Emoji(symbol: "👍", shortcode: "thumbs_up", tags: ["hand"])
        let tagOnly = Emoji(symbol: "🖐️", shortcode: "hand_with_fingers_splayed", tags: ["thumbs_up"])
        let index = EmojiIndex(emojis: [tagOnly, exact])

        #expect(index.search("thumbs-up").first?.emoji == exact)
    }

    @Test("Recent history breaks equal-quality ties")
    func recentHistoryBreaksQualityTies() {
        let currencyExchange = Emoji(
            symbol: "💱",
            shortcode: "currency_exchange",
            tags: ["currency", "exchange"]
        )
        let faceExhaling = Emoji(
            symbol: "😮‍💨",
            shortcode: "face_exhaling",
            tags: ["face", "exhaling"]
        )
        let index = EmojiIndex(emojis: [faceExhaling, currencyExchange])

        #expect(index.search("ex").first?.emoji == currencyExchange)
        #expect(
            index.search("ex", recentEmojiIDs: [faceExhaling.id]).first?.emoji
                == faceExhaling
        )
    }

    @Test("Recency outranks match source within the same quality tier")
    func recentTagMatchOutranksUnusedShortcodeMatch() {
        let explodingHead = Emoji(
            symbol: "🤯",
            shortcode: "exploding_head",
            tags: ["exploding", "head"]
        )
        let faceExhaling = Emoji(
            symbol: "😮‍💨",
            shortcode: "face_exhaling",
            tags: ["face", "exhaling"]
        )
        let index = EmojiIndex(emojis: [faceExhaling, explodingHead])

        #expect(index.search("ex").first?.emoji == explodingHead)
        #expect(
            index.search("ex", recentEmojiIDs: [faceExhaling.id]).first?.emoji
                == faceExhaling
        )
    }

    @Test("Recent history does not override stronger match quality")
    func strongerMatchQualityWins() {
        let exact = Emoji(symbol: "1", shortcode: "ex", tags: [])
        let recentPrefix = Emoji(symbol: "2", shortcode: "extra", tags: [])
        let index = EmojiIndex(emojis: [recentPrefix, exact])

        #expect(
            index.search("ex", recentEmojiIDs: [recentPrefix.id]).map(\.emoji)
                == [exact, recentPrefix]
        )
    }

    @Test("Recent emojis are newest-first within a quality tier")
    func recentMatchesAreNewestFirst() {
        let first = Emoji(symbol: "1", shortcode: "first", tags: ["example"])
        let second = Emoji(symbol: "2", shortcode: "second", tags: ["examine"])
        let unused = Emoji(symbol: "3", shortcode: "third", tags: ["exit"])
        let index = EmojiIndex(emojis: [unused, first, second])

        #expect(
            index.search("ex", recentEmojiIDs: [second.id, first.id]).map(\.emoji)
                == [second, first, unused]
        )
    }

    @Test("An empty query shows recent emojis before database order")
    func emptyQueryShowsRecents() {
        let first = Emoji(symbol: "1", shortcode: "first", tags: [])
        let second = Emoji(symbol: "2", shortcode: "second", tags: [])
        let third = Emoji(symbol: "3", shortcode: "third", tags: [])
        let index = EmojiIndex(emojis: [first, second, third])

        #expect(
            index.search("", recentEmojiIDs: [third.id, first.id]).map(\.emoji)
                == [third, first, second]
        )
    }
}

@Suite("Emoji usage history")
@MainActor
struct EmojiUsageHistoryTests {
    @Test("History persists unique MRU entries and keeps the newest 100")
    func persistsBoundedHistory() throws {
        let suiteName = "ColonDTests.EmojiUsageHistory.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let emojis = (0..<105).map {
            Emoji(symbol: "emoji-\($0)", shortcode: "emoji_\($0)", tags: [])
        }
        let validEmojiIDs = Set(emojis.map(\.id))
        let history = EmojiUsageHistory(
            defaults: defaults,
            validEmojiIDs: validEmojiIDs
        )

        for emoji in emojis {
            history.record(emoji)
        }
        history.record(emojis[50])

        #expect(history.recentEmojiIDs.count == 100)
        #expect(history.recentEmojiIDs.first == emojis[50].id)
        #expect(history.recentEmojiIDs.filter { $0 == emojis[50].id }.count == 1)
        #expect(!history.recentEmojiIDs.contains(emojis[0].id))

        let reloadedHistory = EmojiUsageHistory(
            defaults: defaults,
            validEmojiIDs: validEmojiIDs
        )
        #expect(reloadedHistory.recentEmojiIDs == history.recentEmojiIDs)
    }

    @Test("History ignores stale and duplicate persisted IDs")
    func sanitizesPersistedHistory() throws {
        let suiteName = "ColonDTests.EmojiUsageHistory.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(["stale", "valid", "valid"], forKey: "ColonD.recentEmojiIDs")
        let history = EmojiUsageHistory(
            defaults: defaults,
            validEmojiIDs: ["valid"]
        )

        #expect(history.recentEmojiIDs == ["valid"])
        #expect(defaults.stringArray(forKey: "ColonD.recentEmojiIDs") == ["valid"])
    }
}

@Suite("Pasteboard replacement")
@MainActor
struct PasteboardReplacementCoordinatorTests {
    @Test("Restores clipboard contents after a replacement")
    func restoresOriginalContents() async throws {
        let pasteboard = MockReplacementPasteboard(initialString: "original")
        let coordinator = PasteboardReplacementCoordinator(
            pasteboard: pasteboard,
            restoreDelay: 0.01
        )

        #expect(coordinator.prepareReplacementString("😀"))
        #expect(pasteboard.string(forType: .string) == "😀")

        try await Task.sleep(for: .milliseconds(50))
        #expect(pasteboard.string(forType: .string) == "original")
    }

    @Test("Does not overwrite a newer clipboard change")
    func preservesNewClipboardContents() async throws {
        let pasteboard = MockReplacementPasteboard(initialString: "original")
        let coordinator = PasteboardReplacementCoordinator(
            pasteboard: pasteboard,
            restoreDelay: 0.01
        )

        #expect(coordinator.prepareReplacementString("😀"))
        pasteboard.replaceContents(with: "new copy")

        try await Task.sleep(for: .milliseconds(50))
        #expect(pasteboard.string(forType: .string) == "new copy")
    }
}

@MainActor
private final class MockReplacementPasteboard: ReplacementPasteboard {
    private var items: [NSPasteboardItem] = []
    private(set) var changeCount = 0

    var pasteboardItems: [NSPasteboardItem]? {
        items
    }

    init(initialString: String) {
        replaceContents(with: initialString)
    }

    @discardableResult
    func clearContents() -> Int {
        changeCount += 1
        items = []
        return changeCount
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        let item = items.first ?? NSPasteboardItem()
        if items.isEmpty {
            items = [item]
        }
        return item.setString(string, forType: dataType)
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        items.first?.string(forType: dataType)
    }

    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool {
        items = objects.compactMap { $0 as? NSPasteboardItem }
        return items.count == objects.count
    }

    func replaceContents(with string: String) {
        _ = clearContents()
        _ = setString(string, forType: .string)
    }
}
