import AppKit

enum AccessibilityValueReader {
    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        guard let focusedObject = object(kAXFocusedUIElementAttribute, from: system) else {
            return nil
        }
        return element(from: focusedObject)
    }

    static func element(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        guard let object = object(attribute, from: element) else { return nil }
        return self.element(from: object)
    }

    static func object(_ attribute: String, from element: AXUIElement) -> AnyObject? {
        var object: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                element,
                attribute as CFString,
                &object
            ) == .success, let object
        else {
            return nil
        }

        return object
    }

    static func element(from object: AnyObject) -> AXUIElement? {
        guard CFGetTypeID(object) == AXUIElementGetTypeID() else {
            return nil
        }

        return (object as! AXUIElement)
    }

    static func range(_ attribute: String, from element: AXUIElement) -> CFRange? {
        guard let object = object(attribute, from: element) else { return nil }
        return range(from: object)
    }

    static func string(_ attribute: String, from element: AXUIElement) -> String? {
        object(attribute, from: element) as? String
    }

    static func stringForRange(_ range: CFRange, from element: AXUIElement) -> String? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return nil
        }

        var object: AnyObject?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &object
            ) == .success
        else {
            return nil
        }

        return object as? String
    }

    static func setRange(_ range: CFRange, for attribute: String, in element: AXUIElement) -> Bool {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            rangeValue
        ) == .success
    }

    static func range(from object: AnyObject) -> CFRange? {
        guard let value = axValue(from: object) else { return nil }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private static func axValue(from object: AnyObject) -> AXValue? {
        guard CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }

        return (object as! AXValue)
    }
}
