import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var menuController: MenuBarController?
    private var inputMonitor: GlobalInputMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let emojiIndex = EmojiIndex(emojis: EmojiDatabase.all)
        let permissionGate = PermissionGate()
        let permissionStatus = PermissionStatusMonitor(permissions: permissionGate)
        let activeTextContext = ActiveTextContext()
        let pickerViewModel = PickerViewModel()
        let pickerController = PickerWindowController(viewModel: pickerViewModel)
        let pickerSession = PickerSessionController(
            emojiIndex: emojiIndex,
            viewModel: pickerViewModel,
            windowController: pickerController
        )

        let inputMonitor = GlobalInputMonitor(
            appState: appState,
            permissionStatus: permissionStatus,
            pickerSession: pickerSession,
            activeTextContext: activeTextContext
        )
        self.inputMonitor = inputMonitor

        menuController = MenuBarController(
            appState: appState,
            permissionStatus: permissionStatus,
            onEnableChanged: { [weak inputMonitor] isEnabled in
                isEnabled ? inputMonitor?.start() : inputMonitor?.stop()
            }
        )

        if appState.isEnabled {
            inputMonitor.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputMonitor?.stop()
    }
}
