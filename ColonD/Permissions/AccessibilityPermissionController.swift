import AppKit

struct AccessibilityPermissionController {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestIfNeeded() {
        guard !isTrusted else { return }
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    func openSettings() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
