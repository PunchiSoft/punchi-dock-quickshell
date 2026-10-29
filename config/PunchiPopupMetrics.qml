// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami

// Proportions and colours shared by every popup surface: folder containers, the
// dock context menu and its sections. Every value comes from Kirigami, so the
// popup follows the active KDE scheme and the platform metrics instead of
// carrying its own numbers. A row grows with its glyph, as the reference popup
// and the native delegate do.
QtObject {
    id: root

    // Presentation scale and one base glyph per presentation, all chosen in
    // Settings. Zero means the theme's token, so an untouched profile inherits
    // the platform size; the scale multiplies whichever base applies.
    property real scale: 1
    property int iconSize: 0
    property int listBaseIconSize: 0
    property int fanBaseIconSize: 0

    readonly property FontMetrics labelMetrics: FontMetrics {
        font: Kirigami.Theme.defaultFont
    }
    readonly property FontMetrics descriptionMetrics: FontMetrics {
        font: Kirigami.Theme.smallFont
    }
    // Resting width of a list label: the popup sizes itself from the same cap the
    // row paints, so a long entry cannot reserve room no row will ever use.
    // PunchiEntryMarqueeLabel measures the same probe with the row font.
    readonly property real maximumRestingNameWidth: Math.ceil(
        root.labelMetrics.advanceWidth("MMMMMMMMMM"))
    readonly property int listIconSize: Math.round((root.listBaseIconSize > 0
        ? root.listBaseIconSize : Kirigami.Units.iconSizes.medium) * root.scale)
    readonly property int gridIconSize: Math.round((root.iconSize > 0
        ? root.iconSize : Kirigami.Units.iconSizes.large) * root.scale)
    readonly property int fanIconSize: Math.round((root.fanBaseIconSize > 0
        ? root.fanBaseIconSize : Kirigami.Units.iconSizes.large) * root.scale)
    readonly property int rowPadding: Kirigami.Units.smallSpacing
    readonly property real listRowHeight: root.listIconSize + root.rowPadding * 2
    readonly property real detailRowHeight: Math.max(root.listRowHeight,
        root.labelMetrics.height + root.descriptionMetrics.height + root.rowPadding * 2)
    readonly property real gridCellWidth: root.gridIconSize + Kirigami.Units.largeSpacing * 3
    readonly property real gridCellHeight: root.gridIconSize + root.labelMetrics.height
        + Kirigami.Units.largeSpacing * 3
    // The native delegate radius and hairline, as Breeze paints them.
    readonly property real rowRadius: Kirigami.Units.cornerRadius
    readonly property real rowInset: Kirigami.Units.smallSpacing / 2
    readonly property int rowBorderWidth: Math.max(1,
        Math.round(Kirigami.Units.smallSpacing / 4))
    // Native emphasis: a translucent band of the accent with a hairline of the
    // same colour for the pointer and the keyboard, and the solid highlight with
    // highlighted text for a selection. The third is the share of accent the
    // native band carries.
    readonly property real hoverAlpha: 0.3
    readonly property color rowHoverColor: Qt.alpha(Kirigami.Theme.highlightColor,
        root.hoverAlpha)
    readonly property color rowHoverBorderColor: Kirigami.Theme.highlightColor
    readonly property color rowSelectedColor: Kirigami.Theme.highlightColor
    readonly property color rowSelectedTextColor: Kirigami.Theme.highlightedTextColor
    readonly property int indicatorThickness: Kirigami.Units.smallSpacing
    // The strip the indicator paints in. Consumers reserve it only while their
    // content really scrolls, so the surface collapses back when it fits.
    readonly property int indicatorGutter: root.indicatorThickness
        + Kirigami.Units.smallSpacing * 2
    readonly property int maximumGridColumns: 5
}
