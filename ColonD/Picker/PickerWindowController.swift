import AppKit
import SwiftUI

@MainActor
final class PickerWindowController {
    private let viewModel: PickerViewModel
    private lazy var panel: NSPanel = makePanel()
    var onSelect: ((EmojiMatch) -> Void)?

    init(viewModel: PickerViewModel) {
        self.viewModel = viewModel
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        guard !viewModel.matches.isEmpty else {
            hide()
            return
        }

        resizeForCurrentMatches()
        let origin = centeredOrigin()
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let hostingView = NSHostingView(
            rootView: EmojiPickerView(viewModel: viewModel) { [weak self] match in
                self?.onSelect?(match)
            }
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: PickerMetrics.width,
            height: PickerMetrics.height(for: PickerMetrics.visibleRowLimit)
        )
        hostingView.autoresizingMask = [.width, .height]

        let glassView = NSGlassEffectView(frame: hostingView.frame)
        glassView.autoresizingMask = [.width, .height]
        glassView.style = .regular
        glassView.cornerRadius = PickerMetrics.cornerRadius
        glassView.tintColor = NSColor.black.withAlphaComponent(0.18)
        glassView.contentView = hostingView

        let panel = NSPanel(
            contentRect: glassView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = glassView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        return panel
    }

    private func resizeForCurrentMatches() {
        panel.setContentSize(
            NSSize(
                width: PickerMetrics.width,
                height: PickerMetrics.height(for: viewModel.matches.count)
            )
        )
    }

    private func centeredOrigin() -> CGPoint {
        let panelSize = panel.frame.size
        let frame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        return CGPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.midY - panelSize.height / 2
        )
    }
}
