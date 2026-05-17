import AppKit

@MainActor
final class GlobalInputMonitor {
    private let appState: AppState
    private let permissionStatus: PermissionStatusMonitor
    private let pickerSession: PickerSessionController
    private let replacementEngine: TextReplacementEngine
    private let activeTextContext: ActiveTextContext
    private let focusedTextSynchronizer: FocusedTextSynchronizer
    private lazy var eventTaps = InputEventTaps(
        onTrackingKey: { [weak self] keyInfo in
            self?.handleTrackingKey(keyInfo) ?? true
        },
        onControlKey: { [weak self] keyInfo in
            self?.handleControlKey(keyInfo) ?? true
        }
    )
    private lazy var permissionCoordinator = InputMonitorPermissionCoordinator(
        appState: appState,
        permissionStatus: permissionStatus
    )
    private var keyInputInterpreter = KeyInputInterpreter()
    private let replacementOperations = ReplacementOperationTracker()

    init(
        appState: AppState,
        permissionStatus: PermissionStatusMonitor,
        pickerSession: PickerSessionController,
        activeTextContext: ActiveTextContext
    ) {
        self.appState = appState
        self.permissionStatus = permissionStatus
        self.pickerSession = pickerSession
        self.activeTextContext = activeTextContext
        replacementEngine = TextReplacementEngine(activeTextContext: activeTextContext)
        focusedTextSynchronizer = FocusedTextSynchronizer(activeTextContext: activeTextContext)
        self.pickerSession.onSelect = { [weak self] match in
            self?.confirm(match)
        }
    }

    func start() {
        guard !eventTaps.isTracking else { return }

        switch permissionCoordinator.prepareToStart(onReady: { [weak self] in self?.start() }) {
        case .ready:
            break
        case .waitingForPermissions:
            return
        }

        do {
            try eventTaps.startTracking()
        } catch {
            handleTrackingTapStartFailure()
        }
    }

    func stop() {
        permissionCoordinator.stopWaiting()
        eventTaps.stopTracking()
        resetInputState()
    }

    private func handleTrackingKey(_ keyInfo: KeyInfo) -> Bool {
        guard appState.isEnabled, !replacementOperations.isPending, !keyInfo.isReplacementEvent
        else {
            return true
        }
        guard permissionStatus.isReady else {
            suspendUntilPermissionsAreReady()
            return true
        }
        guard !pickerSession.isVisible || !pickerSession.isControlKey(keyInfo) else {
            return true
        }

        let isReplacingSelection = activeTextContext.currentSelectionRange()?.length ?? 0 > 0

        // Let the focused app receive the key before deriving our next input state.
        DispatchQueue.main.async { [weak self] in
            self?.handleForwardedKey(keyInfo, isReplacingSelection: isReplacingSelection)
        }
        return true
    }

    private func handleControlKey(_ keyInfo: KeyInfo) -> Bool {
        guard appState.isEnabled, !keyInfo.isReplacementEvent else { return true }
        guard !replacementOperations.isPending else { return false }
        guard pickerSession.isVisible else { return true }
        guard permissionStatus.isReady else {
            suspendUntilPermissionsAreReady()
            return true
        }

        return !pickerSession.handleControlKey(
            keyInfo,
            onConfirm: { [weak self] match in
                self?.confirm(match)
            },
            onDismiss: { [weak self] characters in
                self?.dismiss(allowFutureTriggerAfter: characters)
            }
        )
    }

    private func handleForwardedKey(_ keyInfo: KeyInfo, isReplacingSelection: Bool) {
        guard appState.isEnabled, !keyInfo.isReplacementEvent else { return }
        perform(
            keyInputInterpreter.handle(
                keyInfo,
                isAtStartOfText: focusedTextSynchronizer.isCurrentInsertionPointAtStart(
                    after: keyInfo
                ),
                isReplacingSelection: isReplacingSelection
            )
        )
    }

    private func schedulePickerUpdate(query: String) {
        focusedTextSynchronizer.invalidate()
        updatePicker(query: query)
    }

    private func scheduleFocusedTextReconciliation(
        request: KeyInputInterpreter.FocusedTextReconciliationRequest
    ) {
        focusedTextSynchronizer.scheduleAfterFocusedAppEdit { [weak self] in
            self?.reconcileWithFocusedElement(request: request)
        }
    }

    private func reconcileWithFocusedElement(
        request: KeyInputInterpreter.FocusedTextReconciliationRequest
    ) {
        guard
            let textBeforeCaret = focusedTextSynchronizer.currentTextBeforeInsertionPoint(
                maxLength: request.readLength
            )
        else {
            if request.dismissesWhenTextUnavailable {
                dismiss(allowFutureTriggerAfter: nil)
            }
            return
        }

        perform(
            keyInputInterpreter.reconcile(
                textBeforeCaret: textBeforeCaret,
                request: request
            )
        )
    }

    private func updatePicker(query: String) {
        if pickerSession.update(query: query) {
            guard eventTaps.startControl() else {
                dismiss(allowFutureTriggerAfter: nil)
                return
            }
        } else {
            eventTaps.stopControl()
        }
    }

    private func confirm(_ match: EmojiMatch) {
        guard !replacementOperations.isPending else { return }
        guard let trackedTriggerText = keyInputInterpreter.trackedTriggerText else { return }

        let replacementID = replacementOperations.begin()
        eventTaps.stopControl()

        replacementEngine.replace(triggerText: trackedTriggerText, with: match.emoji.symbol) {
            [weak self] result in
            guard let self else { return }
            guard self.replacementOperations.complete(id: replacementID) else { return }

            guard result == .pastePosted else {
                self.dismiss(allowFutureTriggerAfter: nil)
                return
            }

            self.keyInputInterpreter.confirmSelection()
            self.closePicker()
        }
    }

    private func dismiss(allowFutureTriggerAfter characters: String?) {
        _ = keyInputInterpreter.dismiss(allowsFutureTriggerAfter: characters)
        closePicker()
    }

    private func perform(_ action: KeyInputInterpreter.Action) {
        switch action {
        case .none:
            break
        case .updatePicker(let query):
            schedulePickerUpdate(query: query)
        case .dismiss:
            closePicker()
        case .reconcileFocusedText(let request):
            scheduleFocusedTextReconciliation(request: request)
        }
    }

    private func closePicker() {
        replacementOperations.cancel()
        pickerSession.close()
        eventTaps.stopControl()
        focusedTextSynchronizer.invalidate()
    }

    private func resetInputState() {
        closePicker()
        keyInputInterpreter.reset()
    }

    private func suspendUntilPermissionsAreReady() {
        permissionCoordinator.suspendUntilReady(
            onSuspend: { [weak self] in
                self?.eventTaps.stopTracking()
                self?.resetInputState()
            },
            onReady: { [weak self] in
                self?.start()
            }
        )
    }

    private func handleTrackingTapStartFailure() {
        permissionStatus.refresh()

        guard !permissionStatus.isReady else {
            resetInputState()
            return
        }

        permissionCoordinator.waitUntilReady { [weak self] in
            self?.start()
        }
    }
}
