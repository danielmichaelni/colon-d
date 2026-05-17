import Foundation

@MainActor
final class FocusedTextSynchronizer {
    private enum Timing {
        static let focusedAppEditDelay: TimeInterval = 0.02
    }

    private let activeTextContext: ActiveTextContext
    private var revision = 0

    init(activeTextContext: ActiveTextContext) {
        self.activeTextContext = activeTextContext
    }

    func invalidate() {
        revision += 1
    }

    func scheduleAfterFocusedAppEdit(_ work: @escaping () -> Void) {
        revision += 1
        let scheduledRevision = revision

        // AX text can lag key events in host apps, especially after delete,
        // paste, and selection replacement. This short heuristic delay gives
        // the focused app a run-loop window to apply the edit before we reconcile.
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.focusedAppEditDelay) {
            [weak self] in
            guard let self, scheduledRevision == self.revision else { return }
            work()
        }
    }

    func currentTextBeforeInsertionPoint(maxLength: Int) -> String? {
        activeTextContext.currentTextBeforeInsertionPoint(maxLength: maxLength)
    }

    func isCurrentInsertionPointAtStart(after keyInfo: KeyInfo) -> Bool {
        guard let characters = keyInfo.characters else { return false }
        return activeTextContext.currentSelectionRange()?.location == characters.utf16.count
    }
}
