import AppKit
import SwiftUI

struct EmojiPickerView: View {
    @ObservedObject var viewModel: PickerViewModel
    let onSelect: (EmojiMatch) -> Void

    var body: some View {
        EmojiPickerScrollView(viewModel: viewModel, onSelect: onSelect)
            .padding(.vertical, PickerMetrics.verticalPadding / 2)
            .padding(.horizontal, PickerMetrics.sidePadding)
            .frame(width: PickerMetrics.width)
    }
}

private struct EmojiPickerScrollView: NSViewRepresentable {
    @ObservedObject var viewModel: PickerViewModel
    let onSelect: (EmojiMatch) -> Void

    // Native SwiftUI ScrollView did not reliably repaint updated search results
    // inside the non-activating glass NSPanel. Keep this AppKit bridge so row
    // content is explicitly replaced when PickerViewModel changes.
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = viewModel.matches.count <= PickerMetrics.visibleRowLimit
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.verticalScroller?.controlSize = .small
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none

        let hostingView = NSHostingView(rootView: AnyView(rows))
        hostingView.isFlipped = true
        hostingView.frame = NSRect(origin: .zero, size: contentSize(for: scrollView))
        scrollView.documentView = hostingView
        context.coordinator.hostingView = hostingView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let contentSize = contentSize(for: scrollView)
        context.coordinator.hostingView?.rootView = AnyView(rows)
        context.coordinator.hostingView?.frame = NSRect(origin: .zero, size: contentSize)
        scrollView.autohidesScrollers = viewModel.matches.count <= PickerMetrics.visibleRowLimit
        scrollView.hasVerticalScroller = viewModel.matches.count > PickerMetrics.visibleRowLimit
        scrollSelectedRowIntoView(scrollView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var rows: some View {
        LazyVStack(spacing: PickerMetrics.rowSpacing) {
            ForEach(Array(viewModel.matches.enumerated()), id: \.element.id) { index, match in
                EmojiPickerRow(
                    match: match,
                    isSelected: index == viewModel.selectedIndex
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PickerMetrics.rowCornerRadius,
                        style: .continuous
                    )
                )
                .onTapGesture {
                    onSelect(match)
                }
            }
        }
    }

    private func contentSize(for scrollView: NSScrollView) -> NSSize {
        let width =
            scrollView.contentView.bounds.width > 0
            ? scrollView.contentView.bounds.width
            : PickerMetrics.width - PickerMetrics.horizontalPadding
        return NSSize(
            width: width,
            height: PickerMetrics.contentHeight(for: viewModel.matches.count)
        )
    }

    private func scrollSelectedRowIntoView(_ scrollView: NSScrollView) {
        guard viewModel.matches.indices.contains(viewModel.selectedIndex) else { return }

        let rowStride = PickerMetrics.rowHeight + PickerMetrics.rowSpacing
        let selectedY = CGFloat(viewModel.selectedIndex) * rowStride
        let selectedRect = NSRect(
            x: 0,
            y: selectedY,
            width: scrollView.contentView.bounds.width,
            height: PickerMetrics.rowHeight
        )
        scrollView.documentView?.scrollToVisible(selectedRect)
    }

    final class Coordinator {
        var hostingView: NSHostingView<AnyView>?
    }
}

private struct EmojiPickerRow: View {
    let match: EmojiMatch
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(match.emoji.symbol)
                .font(.system(size: 24))
                .frame(width: 34, height: 34)

            Text(match.emoji.shortcode)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.82))
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .frame(height: PickerMetrics.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: PickerMetrics.rowCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: PickerMetrics.rowCornerRadius,
                            style: .continuous
                        )
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
        }
    }
}
