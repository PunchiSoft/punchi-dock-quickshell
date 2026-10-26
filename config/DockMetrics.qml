// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.kirigami as Kirigami

QtObject {
    // Compact proportions from the reference, expressed through KDE metrics.
    readonly property int iconSize: Math.round(
        (Kirigami.Units.iconSizes.medium + Kirigami.Units.iconSizes.large) / 2)
    readonly property int itemSize: iconSize + Kirigami.Units.smallSpacing
    readonly property real maximumMagnifiedIconSize: iconSize * 3
    readonly property int spacing: Math.round(Kirigami.Units.smallSpacing / 2)
    readonly property int padding: Kirigami.Units.smallSpacing
    readonly property int bottomContentPadding: Kirigami.Units.mediumSpacing
    readonly property real runningMarkerSize: Kirigami.Units.smallSpacing
    // A count badge is one Kirigami icon-size step: 16 px against the default
    // 40 px launcher icon, the same share KDE's notification badges use. The
    // magnification scale grows it with the icon; no arbitrary pixel size.
    readonly property int badgeBaseSize: Kirigami.Units.iconSizes.small
    readonly property int badgeFontPixelSize: Kirigami.Theme.smallFont.pixelSize
    // Overlap into the icon corner, so the disc touches the icon the way a
    // system notification badge does.
    readonly property real badgeInset: Kirigami.Units.smallSpacing
    readonly property int edgeMargin: Kirigami.Units.smallSpacing
    readonly property real surfaceRadius: Kirigami.Units.cornerRadius * 2
        + Kirigami.Units.smallSpacing
    readonly property real borderWidth: Kirigami.Units.smallSpacing / 4
}
