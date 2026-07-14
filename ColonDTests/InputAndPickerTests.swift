import AppKit
import Carbon
import Testing

@testable import ColonD

@Suite("Picker control keys")
@MainActor
struct PickerControlKeyTests {
    private func makeSession() -> PickerSessionController {
        let viewModel = PickerViewModel()
        return PickerSessionController(
            emojiIndex: EmojiIndex(emojis: []),
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
