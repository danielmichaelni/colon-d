import Carbon
import Foundation

@MainActor
final class PickerSessionController {
    var onSelect: ((EmojiMatch) -> Void)? {
        didSet {
            windowController.onSelect = onSelect
        }
    }

    private let emojiIndex: EmojiIndex
    private let viewModel: PickerViewModel
    private let windowController: PickerWindowController

    init(
        emojiIndex: EmojiIndex,
        viewModel: PickerViewModel,
        windowController: PickerWindowController
    ) {
        self.emojiIndex = emojiIndex
        self.viewModel = viewModel
        self.windowController = windowController
    }

    var isVisible: Bool {
        windowController.isVisible
    }

    var selectedMatch: EmojiMatch? {
        viewModel.selectedMatch
    }

    func selectNext() {
        viewModel.selectNext()
    }

    func selectPrevious() {
        viewModel.selectPrevious()
    }

    func isControlKey(_ keyInfo: KeyInfo) -> Bool {
        ControlKey(keyInfo) != nil
    }

    /// Returns true when the picker should consume the key event.
    func handleControlKey(
        _ keyInfo: KeyInfo,
        onConfirm: (EmojiMatch) -> Void,
        onDismiss: (String?) -> Void
    ) -> Bool {
        guard let controlKey = ControlKey(keyInfo) else { return false }

        switch controlKey {
        case .next:
            selectNext()
        case .previous:
            selectPrevious()
        case .confirm:
            if let selectedMatch {
                onConfirm(selectedMatch)
            }
        case .dismiss:
            onDismiss(keyInfo.characters)
        }

        return true
    }

    func update(query: String) -> Bool {
        viewModel.update(query: query, matches: emojiIndex.search(query))
        windowController.show()
        return windowController.isVisible
    }

    func close() {
        windowController.hide()
    }
}

private enum ControlKey {
    case next
    case previous
    case confirm
    case dismiss

    init?(_ keyInfo: KeyInfo) {
        guard !keyInfo.usesPickerControlModifier else { return nil }

        switch keyInfo.keyCode {
        case CGKeyCode(kVK_DownArrow):
            self = .next
        case CGKeyCode(kVK_UpArrow):
            self = .previous
        case CGKeyCode(kVK_Return), CGKeyCode(kVK_Tab):
            self = .confirm
        case CGKeyCode(kVK_Escape):
            self = .dismiss
        default:
            return nil
        }
    }
}
