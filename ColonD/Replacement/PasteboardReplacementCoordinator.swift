import AppKit

@MainActor
final class PasteboardReplacementCoordinator {
    private enum State {
        case idle
        case owned(marker: String, originalSnapshot: PasteboardSnapshot, changeCount: Int)
    }

    private let pasteboard: ReplacementPasteboard
    private let markerType = NSPasteboard.PasteboardType(
        "com.danielmichaelni.ColonD.replacementMarker"
    )
    private let restoreDelay: TimeInterval = 1

    private var state = State.idle
    private var restoreWorkItem: DispatchWorkItem?

    init(pasteboard: ReplacementPasteboard) {
        self.pasteboard = pasteboard
    }

    func prepareReplacementString(_ string: String) -> Bool {
        restoreWorkItem?.cancel()

        let originalSnapshot = currentOriginalSnapshot()
        let marker = UUID().uuidString

        _ = pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string),
            pasteboard.setString(marker, forType: markerType)
        else {
            originalSnapshot.restore(to: pasteboard)
            state = .idle
            restoreWorkItem = nil
            return false
        }

        state = .owned(
            marker: marker,
            originalSnapshot: originalSnapshot,
            changeCount: pasteboard.changeCount
        )

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.restoreIfReplacementIsCurrent(marker: marker)
            }
        }
        restoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: workItem)
        return true
    }

    private func currentOriginalSnapshot() -> PasteboardSnapshot {
        if case .owned(let marker, let originalSnapshot, let changeCount) = state,
            pasteboard.changeCount == changeCount,
            pasteboard.string(forType: markerType) == marker
        {
            return originalSnapshot
        }

        return PasteboardSnapshot(items: pasteboard.pasteboardItems ?? [])
    }

    private func restoreIfReplacementIsCurrent(marker: String) {
        guard case .owned(let currentMarker, let originalSnapshot, let changeCount) = state,
            currentMarker == marker
        else {
            return
        }

        defer {
            state = .idle
            restoreWorkItem = nil
        }

        guard pasteboard.changeCount == changeCount,
            pasteboard.string(forType: markerType) == marker
        else {
            return
        }

        originalSnapshot.restore(to: pasteboard)
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(items: [NSPasteboardItem]) {
        self.items = items.map { item in
            item.types.reduce(into: [:]) { result, type in
                result[type] = item.data(forType: type)
            }
        }
    }

    func restore(to pasteboard: ReplacementPasteboard) {
        _ = pasteboard.clearContents()
        let restoredItems = items.map { itemData in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }
        _ = pasteboard.writeObjects(restoredItems)
    }
}

protocol ReplacementPasteboard: AnyObject {
    var changeCount: Int { get }
    var pasteboardItems: [NSPasteboardItem]? { get }

    func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool
}

extension NSPasteboard: ReplacementPasteboard {}
