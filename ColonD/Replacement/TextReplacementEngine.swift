import AppKit
import Carbon

@MainActor
final class TextReplacementEngine {
    enum ReplacementResult: Equatable {
        case pastePosted
        case failed
    }

    private enum Timing {
        static let selectionUpdateDelay: TimeInterval = 0.02
    }

    private let pasteboardCoordinator = PasteboardReplacementCoordinator(
        pasteboard: NSPasteboard.general
    )
    private let activeTextContext: ActiveTextContext

    init(activeTextContext: ActiveTextContext) {
        self.activeTextContext = activeTextContext
    }

    func replace(
        triggerText: String,
        with emoji: String,
        onComplete: @escaping (ReplacementResult) -> Void
    ) {
        guard let replacement = prepareReplacement(triggerText: triggerText, emoji: emoji) else {
            fail(onComplete)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.selectionUpdateDelay) {
            [weak self] in
            guard let self else {
                _ = replacement.activeTextContext.setSelectionRange(
                    replacement.originalSelectionRange
                )
                onComplete(.failed)
                return
            }

            guard replacement.isStillSelected else {
                restoreSelection(replacement.originalSelectionRange)
                self.fail(onComplete)
                return
            }

            pastePreparedReplacement()
            DispatchQueue.main.async {
                onComplete(.pastePosted)
            }
        }
    }

    private func prepareReplacement(
        triggerText: String,
        emoji: String
    ) -> PreparedReplacement? {
        guard !triggerText.isEmpty else { return nil }
        guard currentTextEndsWithTrigger(triggerText) else { return nil }
        guard let originalSelectionRange = activeTextContext.currentSelectionRange() else {
            return nil
        }
        guard selectTriggerText(triggerText) else { return nil }

        guard pasteboardCoordinator.prepareReplacementString(emoji) else {
            restoreSelection(originalSelectionRange)
            return nil
        }

        return PreparedReplacement(
            triggerText: triggerText,
            originalSelectionRange: originalSelectionRange,
            activeTextContext: activeTextContext
        )
    }

    private func currentTextEndsWithTrigger(_ triggerText: String) -> Bool {
        activeTextContext.currentTextBeforeInsertionPoint(
            maxLength: triggerText.utf16.count
        ) == triggerText
    }

    private func selectTriggerText(_ triggerText: String) -> Bool {
        activeTextContext.selectTextBeforeInsertionPoint(length: triggerText.utf16.count)
    }

    private func restoreSelection(_ range: CFRange) {
        _ = activeTextContext.setSelectionRange(range)
    }

    private func fail(_ onComplete: @escaping (ReplacementResult) -> Void) {
        NSSound.beep()
        onComplete(.failed)
    }

    private func pastePreparedReplacement() {
        postKey(code: CGKeyCode(kVK_ANSI_V), down: true, flags: .maskCommand)
        postKey(code: CGKeyCode(kVK_ANSI_V), down: false, flags: .maskCommand)
    }

    private func postKey(code: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else {
            return
        }
        SyntheticReplacementEventTag.tag(event)
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

private struct PreparedReplacement {
    let triggerText: String
    let originalSelectionRange: CFRange
    let activeTextContext: ActiveTextContext

    var isStillSelected: Bool {
        activeTextContext.currentSelectedText() == triggerText
    }
}
