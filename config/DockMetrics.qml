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
    readonly property int edgeMargin: Kirigami.Units.smallSpacing
    readonly property real surfaceRadius: Kirigami.Units.cornerRadius * 2
        + Kirigami.Units.smallSpacing
    readonly property real borderWidth: Kirigami.Units.smallSpacing / 4
}
