// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami

// Rounded settings surface shared by the grouped cards, the item list and the
// item details pane. The fill shifts the inherited window background slightly
// toward the theme text color: some schemes resolve the Window and View
// backgrounds to the same color, and a plain background fill would then hide
// both the surface and its rounded corners. Deriving the fill from the active
// scheme keeps the contrast in light and dark themes without a fixed color.
Rectangle {
    id: root
    readonly property color surfaceColor: root.blend(Kirigami.Theme.backgroundColor,
        Kirigami.Theme.textColor, 0.08)
    function blend(base: color, other: color, amount: real): color {
        return Qt.rgba(base.r + (other.r - base.r) * amount,
            base.g + (other.g - base.g) * amount,
            base.b + (other.b - base.b) * amount, 1)
    }
    radius: Kirigami.Units.cornerRadius * 2
    color: root.surfaceColor
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b, 0.16)
    Accessible.ignored: true
}
