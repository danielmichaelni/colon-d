import Foundation

struct InputSessionStateMachine {
    enum Action: Equatable {
        case none
        case updatePicker(query: String)
        case dismiss
        case reconcileFocusedText(FocusedTextReconciliationRequest)
    }

    enum FocusedTextReconciliation: Equatable {
        case trackedTrigger
        case recoverTriggerSuffix
    }

    struct FocusedTextReconciliationRequest: Equatable {
        let reconciliation: FocusedTextReconciliation
        let readLength: Int

        var dismissesWhenTextUnavailable: Bool {
            reconciliation == .trackedTrigger
        }
    }

    private enum Session: Equatable {
        case idle(previousAllowsTrigger: Bool)
        case tracking(query: String)
    }

    private var session: Session = .idle(previousAllowsTrigger: true)

    var trackedTriggerText: String? {
        guard case .tracking(let query) = session else { return nil }
        return ":" + query
    }

    mutating func reset() {
        session = .idle(previousAllowsTrigger: true)
    }

    func focusedTextReconciliationRequest(
        for reconciliation: FocusedTextReconciliation
    ) -> FocusedTextReconciliationRequest? {
        let readLength: Int
        switch reconciliation {
        case .trackedTrigger:
            guard let trackedTriggerText else { return nil }
            readLength = trackedTriggerText.utf16.count
        case .recoverTriggerSuffix:
            readLength = Shortcode.maximumRecoverableTriggerLength
        }

        return FocusedTextReconciliationRequest(
            reconciliation: reconciliation,
            readLength: readLength
        )
    }

    mutating func handleCharacter(
        _ character: Character,
        isAtStartOfText: Bool
    ) -> Action {
        switch session {
        case .idle(let previousAllowsTrigger):
            if character == ":", previousAllowsTrigger || isAtStartOfText {
                session = .tracking(query: "")
                return .updatePicker(query: "")
            }

            session = .idle(previousAllowsTrigger: character.isTriggerBoundary)
            if character == ":" {
                return reconcileFocusedText(.recoverTriggerSuffix)
            }
            return .none

        case .tracking(let query):
            if character.isShortcodeCharacter {
                let characterText = String(character)
                guard query.utf16.count + characterText.utf16.count <= Shortcode.maximumLength
                else {
                    return dismiss(allowsFutureTriggerAfter: characterText)
                }

                let nextQuery = query + characterText
                session = .tracking(query: nextQuery)
                return .updatePicker(query: nextQuery)
            }

            return dismiss(allowsFutureTriggerAfter: String(character))
        }
    }

    mutating func handleNonCharacter() -> Action {
        dismiss(allowsFutureTriggerAfter: nil)
    }

    mutating func reconcile(
        textBeforeCaret: String,
        reconciliation: FocusedTextReconciliation
    ) -> Action {
        switch reconciliation {
        case .trackedTrigger:
            guard case .tracking(let query) = session else { return .none }

            let trackedTriggerText = ":" + query
            guard textBeforeCaret != trackedTriggerText else { return .none }
        case .recoverTriggerSuffix:
            break
        }

        guard let triggerText = textBeforeCaret.currentTriggerSuffix else {
            switch reconciliation {
            case .trackedTrigger:
                return dismiss(allowsFutureTriggerAfter: nil)
            case .recoverTriggerSuffix:
                return .none
            }
        }

        let query = String(triggerText.dropFirst())
        session = .tracking(query: query)
        return .updatePicker(query: query)
    }

    mutating func confirmSelection() {
        session = .idle(previousAllowsTrigger: false)
    }

    mutating func dismiss(allowsFutureTriggerAfter characters: String?) -> Action {
        let allowsTrigger = characters?.last?.isTriggerBoundary ?? true
        session = .idle(previousAllowsTrigger: allowsTrigger)
        return .dismiss
    }

    func reconcileFocusedText(_ reconciliation: FocusedTextReconciliation) -> Action {
        guard let request = focusedTextReconciliationRequest(for: reconciliation) else {
            return .none
        }

        return .reconcileFocusedText(request)
    }

}

private enum Shortcode {
    static let maximumLength = 63
    static let maximumRecoverableTriggerLength = maximumLength + 1
}

extension Character {
    fileprivate var isShortcodeCharacter: Bool {
        isAlphanumeric || self == "_" || self == "-"
    }

    private var isAlphanumeric: Bool {
        unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    fileprivate var isTriggerBoundary: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}

extension String {
    fileprivate var currentTriggerSuffix: String? {
        guard let colonIndex = lastIndex(of: ":") else { return nil }

        if colonIndex > startIndex {
            let beforeColonIndex = index(before: colonIndex)
            guard self[beforeColonIndex].isTriggerBoundary else { return nil }
        }

        let query = self[index(after: colonIndex)...]
        guard query.utf16.count <= Shortcode.maximumLength else { return nil }
        guard query.allSatisfy(\.isShortcodeCharacter) else { return nil }
        return String(self[colonIndex...])
    }
}
