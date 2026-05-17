import AppKit

@MainActor
final class ActiveTextContext {
    func currentSelectionRange() -> CFRange? {
        guard let focusedElement = currentFocusedElement() else {
            return nil
        }

        return selectedTextRange(in: focusedElement)
    }

    func currentTextBeforeInsertionPoint(maxLength: Int) -> String? {
        guard maxLength > 0 else { return "" }
        guard let focusedElement = currentFocusedElement(),
            let selectionRange = selectedTextRange(in: focusedElement),
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
        if let text = AccessibilityValueReader.stringForRange(range, from: focusedElement) {
            return text
        }

        guard let value = AccessibilityValueReader.string(kAXValueAttribute, from: focusedElement)
        else {
            return nil
        }
        let caretOffset = min(selectionRange.location, value.utf16.count)
        let startOffset = max(caretOffset - maxLength, 0)
        let startIndex = String.Index(utf16Offset: startOffset, in: value)
        let caretIndex = String.Index(utf16Offset: caretOffset, in: value)
        return String(value[startIndex..<caretIndex])
    }

    func selectTextBeforeInsertionPoint(length: Int) -> Bool {
        guard length > 0 else { return false }
        guard let focusedElement = currentFocusedElement(),
            let selectionRange = selectedTextRange(in: focusedElement),
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
            in: focusedElement
        )
    }

    func setSelectionRange(_ range: CFRange) -> Bool {
        guard let focusedElement = currentFocusedElement() else {
            return false
        }

        return AccessibilityValueReader.setRange(
            range,
            for: kAXSelectedTextRangeAttribute,
            in: focusedElement
        )
    }

    func currentSelectedText() -> String? {
        guard let focusedElement = currentFocusedElement(),
            let selectionRange = selectedTextRange(in: focusedElement),
            selectionRange.length > 0
        else {
            return nil
        }

        if let text = AccessibilityValueReader.stringForRange(selectionRange, from: focusedElement)
        {
            return text
        }

        guard let value = AccessibilityValueReader.string(kAXValueAttribute, from: focusedElement),
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

    private func currentFocusedElement() -> AXUIElement? {
        AccessibilityValueReader.focusedElement()
    }

    private func selectedTextRange(in focusedElement: AXUIElement) -> CFRange? {
        AccessibilityValueReader.range(kAXSelectedTextRangeAttribute, from: focusedElement)
    }
}
