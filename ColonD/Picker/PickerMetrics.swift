import CoreGraphics

enum PickerMetrics {
    static let width: CGFloat = 340
    static let rowHeight: CGFloat = 42
    static let rowSpacing: CGFloat = 4
    static let visibleRowLimit = 7
    static let cornerRadius: CGFloat = 14
    static let rowCornerRadius: CGFloat = 10
    static let sidePadding: CGFloat = 4
    static let horizontalPadding: CGFloat = sidePadding * 2
    static let verticalPadding: CGFloat = 8

    static func contentHeight(for matchCount: Int) -> CGFloat {
        let rows = max(matchCount, 1)
        return (CGFloat(rows) * rowHeight)
            + (CGFloat(max(rows - 1, 0)) * rowSpacing)
    }

    static func height(for matchCount: Int) -> CGFloat {
        let visibleRows = min(max(matchCount, 1), visibleRowLimit)
        return verticalPadding
            + (CGFloat(visibleRows) * rowHeight)
            + (CGFloat(max(visibleRows - 1, 0)) * rowSpacing)
    }
}
