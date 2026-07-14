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
        in target: ActiveTextContext.FocusedTextTarget,
        triggerText: String,
        with emoji: String,
        onComplete: @escaping (ReplacementResult) -> Void
    ) {
        guard
            let replacement = prepareReplacement(
                in: target,
                triggerText: triggerText,
                emoji: emoji
            )
        else {
            fail(onComplete)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.selectionUpdateDelay) {
            [weak self] in
            guard let self else {
                _ = replacement.activeTextContext.setSelectionRange(
                    replacement.originalSelectionRange,
                    in: replacement.target
                )
                onComplete(.failed)
                return
            }

            guard replacement.isStillSelected else {
                restoreSelection(replacement.originalSelectionRange, in: replacement.target)
                self.fail(onComplete)
                return
            }

            guard pastePreparedReplacement() else {
                restoreSelection(replacement.originalSelectionRange, in: replacement.target)
                self.fail(onComplete)
                return
            }
            DispatchQueue.main.async {
                onComplete(.pastePosted)
            }
        }
    }

    private func prepareReplacement(
        in target: ActiveTextContext.FocusedTextTarget,
        triggerText: String,
        emoji: String
    ) -> PreparedReplacement? {
        guard !triggerText.isEmpty else { return nil }
        guard activeTextContext.isFocused(target) else { return nil }
        guard currentTextEndsWithTrigger(triggerText, in: target) else { return nil }
        guard let originalSelectionRange = activeTextContext.selectionRange(in: target) else {
            return nil
        }
        guard selectTriggerText(triggerText, in: target) else { return nil }

        guard pasteboardCoordinator.prepareReplacementString(emoji) else {
            restoreSelection(originalSelectionRange, in: target)
            return nil
        }

        return PreparedReplacement(
            triggerText: triggerText,
            originalSelectionRange: originalSelectionRange,
            target: target,
            activeTextContext: activeTextContext
        )
    }

    private func currentTextEndsWithTrigger(
        _ triggerText: String,
        in target: ActiveTextContext.FocusedTextTarget
    ) -> Bool {
        activeTextContext.textBeforeInsertionPoint(
            in: target,
            maxLength: triggerText.utf16.count
        ) == triggerText
    }

    private func selectTriggerText(
        _ triggerText: String,
        in target: ActiveTextContext.FocusedTextTarget
    ) -> Bool {
        activeTextContext.selectTextBeforeInsertionPoint(
            in: target,
            length: triggerText.utf16.count
        )
    }

    private func restoreSelection(
        _ range: CFRange,
        in target: ActiveTextContext.FocusedTextTarget
    ) {
        _ = activeTextContext.setSelectionRange(range, in: target)
    }

    private func fail(_ onComplete: @escaping (ReplacementResult) -> Void) {
        NSSound.beep()
        onComplete(.failed)
    }

    private func pastePreparedReplacement() -> Bool {
        guard
            let keyDown = replacementKeyEvent(
                code: CGKeyCode(kVK_ANSI_V),
                down: true,
                flags: .maskCommand
            ),
            let keyUp = replacementKeyEvent(
                code: CGKeyCode(kVK_ANSI_V),
                down: false,
                flags: .maskCommand
            )
        else {
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func replacementKeyEvent(
        code: CGKeyCode,
        down: Bool,
        flags: CGEventFlags = []
    ) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else {
            return nil
        }
        SyntheticReplacementEventTag.tag(event)
        event.flags = flags
        return event
    }
}

private struct PreparedReplacement {
    let triggerText: String
    let originalSelectionRange: CFRange
    let target: ActiveTextContext.FocusedTextTarget
    let activeTextContext: ActiveTextContext

    var isStillSelected: Bool {
        activeTextContext.isFocused(target)
            && activeTextContext.selectedText(in: target) == triggerText
    }
}
