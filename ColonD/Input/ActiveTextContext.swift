import AppKit

@MainActor
final class ActiveTextContext {
    struct FocusedTextTarget: Equatable {
        let element: AXUIElement

        static func == (lhs: Self, rhs: Self) -> Bool {
            CFEqual(lhs.element, rhs.element)
        }
    }

    func currentFocusedTarget() -> FocusedTextTarget? {
        guard let element = AccessibilityValueReader.focusedElement() else {
            return nil
        }
        return FocusedTextTarget(element: element)
    }

    func isFocused(_ target: FocusedTextTarget) -> Bool {
        currentFocusedTarget() == target
    }

    func currentSelectionRange() -> CFRange? {
        guard let target = currentFocusedTarget() else {
            return nil
        }

        return selectionRange(in: target)
    }

    func selectionRange(in target: FocusedTextTarget) -> CFRange? {
        selectedTextRange(in: target.element)
    }

    func currentTextBeforeInsertionPoint(maxLength: Int) -> String? {
        guard let target = currentFocusedTarget() else { return nil }
        return textBeforeInsertionPoint(in: target, maxLength: maxLength)
    }

    func textBeforeInsertionPoint(
        in target: FocusedTextTarget,
        maxLength: Int
    ) -> String? {
        guard maxLength > 0 else { return "" }
        guard
            let selectionRange = selectedTextRange(in: target.element),
            selectionRange.location >= 0,
            selectionRange.length == 0
        else {
            return nil
        }

        let length = min(selectionRange.location, maxLength)
        let range = CFRange(
            location: selectionRange.location - length,
            length: length
        )
        if let text = AccessibilityValueReader.stringForRange(range, from: target.element) {
            return text
        }

        guard let value = AccessibilityValueReader.string(kAXValueAttribute, from: target.element)
        else {
            return nil
        }
        let caretOffset = min(selectionRange.location, value.utf16.count)
        let startOffset = max(caretOffset - maxLength, 0)
        let startIndex = String.Index(utf16Offset: startOffset, in: value)
        let caretIndex = String.Index(utf16Offset: caretOffset, in: value)
        return String(value[startIndex..<caretIndex])
    }

    func selectTextBeforeInsertionPoint(
        in target: FocusedTextTarget,
        length: Int
    ) -> Bool {
        guard length > 0 else { return false }
        guard
            let selectionRange = selectedTextRange(in: target.element),
            selectionRange.location >= length,
            selectionRange.length == 0
        else {
            return false
        }

        let replacementRange = CFRange(
            location: selectionRange.location - length,
            length: length
        )
        return AccessibilityValueReader.setRange(
            replacementRange,
            for: kAXSelectedTextRangeAttribute,
            in: target.element
        )
    }

    func setSelectionRange(_ range: CFRange, in target: FocusedTextTarget) -> Bool {
        return AccessibilityValueReader.setRange(
            range,
            for: kAXSelectedTextRangeAttribute,
            in: target.element
        )
    }

    func selectedText(in target: FocusedTextTarget) -> String? {
        guard
            let selectionRange = selectedTextRange(in: target.element),
            selectionRange.length > 0
        else {
            return nil
        }

        if let text = AccessibilityValueReader.stringForRange(selectionRange, from: target.element)
        {
            return text
        }

        guard let value = AccessibilityValueReader.string(kAXValueAttribute, from: target.element),
            selectionRange.location >= 0,
            selectionRange.location + selectionRange.length <= value.utf16.count
        else {
            return nil
        }

        let startIndex = String.Index(utf16Offset: selectionRange.location, in: value)
        let endIndex = String.Index(
            utf16Offset: selectionRange.location + selectionRange.length,
            in: value
        )
        return String(value[startIndex..<endIndex])
    }

    private func selectedTextRange(in focusedElement: AXUIElement) -> CFRange? {
        AccessibilityValueReader.range(kAXSelectedTextRangeAttribute, from: focusedElement)
    }
}
