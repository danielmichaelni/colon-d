import AppKit
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let appState: AppState
    private let permissionStatus: PermissionStatusMonitor
    private let onEnableChanged: (Bool) -> Void
    private var permissionStatusListenerID: UUID?

    init(
        appState: AppState,
        permissionStatus: PermissionStatusMonitor,
        onEnableChanged: @escaping (Bool) -> Void
    ) {
        self.appState = appState
        self.permissionStatus = permissionStatus
        self.onEnableChanged = onEnableChanged
        super.init()
        menu.delegate = self
        configureStatusItem()
        rebuildMenu()
        permissionStatusListenerID = permissionStatus.addListener { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    deinit {
        let permissionStatus = permissionStatus
        let listenerID = permissionStatusListenerID
        Task { @MainActor in
            permissionStatus.removeListener(listenerID)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        statusItem.length = 24
        button.imagePosition = .imageOnly
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        button.toolTip = "Colon D"
        let needsPermissions = !permissionStatus.snapshot.isReady
        button.image = StatusItemImage.make(showsPermissionIndicator: needsPermissions)
    }

    private func rebuildMenu() {
        updateStatusItem()
        menu.removeAllItems()

        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = appState.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        let permissionsSnapshot = permissionStatus.snapshot
        let needsAccessibility = permissionsSnapshot.needsAccessibility
        let needsInputMonitoring = permissionsSnapshot.needsInputMonitoring
        if needsAccessibility || needsInputMonitoring {
            menu.addItem(.separator())

            if needsAccessibility {
                let permissionItem = NSMenuItem(
                    title: "Accessibility: Needs Permission",
                    action: #selector(openAccessibilitySettings),
                    keyEquivalent: ""
                )
                permissionItem.target = self
                menu.addItem(permissionItem)
            }

            if needsInputMonitoring {
                let inputItem = NSMenuItem(
                    title: "Input Monitoring: Needs Permission",
                    action: #selector(openInputMonitoringSettings),
                    keyEquivalent: ""
                )
                inputItem.target = self
                menu.addItem(inputItem)
            }
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Colon D",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        if statusItem.menu !== menu {
            statusItem.menu = menu
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if !permissionStatus.refresh() {
            rebuildMenu()
        }
    }

    @objc private func toggleEnabled() {
        appState.isEnabled.toggle()
        onEnableChanged(appState.isEnabled)
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }

        rebuildMenu()
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func openAccessibilitySettings() {
        permissions.accessibility.requestIfNeeded()
        permissions.accessibility.openSettings()
        permissionStatus.refresh()
        rebuildMenu()
    }

    @objc private func openInputMonitoringSettings() {
        permissions.inputMonitoring.requestIfNeeded()
        permissions.inputMonitoring.openSettings()
        permissionStatus.refresh()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var permissions: PermissionGate {
        permissionStatus.permissions
    }
}

private enum StatusItemImage {
    static func make(showsPermissionIndicator: Bool) -> NSImage {
        let size = NSSize(width: 24, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        let title = ":D" as NSString
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let titleSize = title.size(withAttributes: attributes)
        let titleRect = NSRect(
            x: (size.width - titleSize.width) / 2,
            y: (size.height - titleSize.height) / 2,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: attributes)

        if showsPermissionIndicator {
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: NSRect(x: 20, y: 12, width: 4, height: 4)).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
