import Carbon
import Foundation

struct KeyInputInterpreter {
    enum Action: Equatable {
        case none
        case updatePicker(query: String)
        case dismiss
        case reconcileFocusedText(FocusedTextReconciliationRequest)
    }

    struct FocusedTextReconciliationRequest: Equatable {
        let readLength: Int
        let dismissesWhenTextUnavailable: Bool

        fileprivate let reconciliation: InputSessionStateMachine.FocusedTextReconciliation
    }

    private var inputSession = InputSessionStateMachine()

    var trackedTriggerText: String? {
        inputSession.trackedTriggerText
    }

    mutating func reset() {
        inputSession.reset()
    }

    mutating func handle(
        _ keyInfo: KeyInfo,
        isAtStartOfText: Bool,
        isReplacingSelection: Bool
    ) -> Action {
        if keyInfo.usesEditingModifier {
            return convert(inputSession.reconcileFocusedText(.trackedTrigger))
        }

        if keyInfo.keyCode == CGKeyCode(kVK_Delete) {
            return convert(inputSession.reconcileFocusedText(.trackedTrigger))
        }

        guard let characters = keyInfo.characters, characters.count == 1 else {
            return convert(inputSession.handleNonCharacter())
        }

        if characters == ":" {
            if isReplacingSelection {
                return convert(inputSession.reconcileFocusedText(.recoverTriggerSuffix))
            }
        }

        let character = characters[characters.startIndex]
        return convert(inputSession.handleCharacter(character, isAtStartOfText: isAtStartOfText))
    }

    mutating func confirmSelection() {
        inputSession.confirmSelection()
    }

    mutating func reconcile(
        textBeforeCaret: String,
        request: FocusedTextReconciliationRequest
    ) -> Action {
        convert(
            inputSession.reconcile(
                textBeforeCaret: textBeforeCaret,
                reconciliation: request.reconciliation
            )
        )
    }

    mutating func dismiss(allowsFutureTriggerAfter characters: String?) -> Action {
        convert(inputSession.dismiss(allowsFutureTriggerAfter: characters))
    }

    private func convert(_ action: InputSessionStateMachine.Action) -> Action {
        switch action {
        case .none:
            return .none
        case .updatePicker(let query):
            return .updatePicker(query: query)
        case .dismiss:
            return .dismiss
        case .reconcileFocusedText(let request):
            return .reconcileFocusedText(
                FocusedTextReconciliationRequest(
                    readLength: request.readLength,
                    dismissesWhenTextUnavailable: request.dismissesWhenTextUnavailable,
                    reconciliation: request.reconciliation
                )
            )
        }
    }
}
