// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami

AntialiasedSurface {
    id: root
    property bool hovered: false
    property bool focused: false
    property bool pressed: false
    property bool outlineOnly: false
    property color highlightColor: Kirigami.Theme.highlightColor
    property real strokeWidth: Kirigami.Units.smallSpacing / 4

    Rectangle {
        objectName: root.outlineOnly ? "launcher-focus-border" : "launcher-highlight"
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 2
        color: root.outlineOnly ? "transparent"
            : root.pressed ? Qt.alpha(root.highlightColor, 0.3)
                : root.hovered || root.focused ? Qt.alpha(root.highlightColor, 0.2) : "transparent"
        border.width: root.outlineOnly && root.focused ? root.strokeWidth : 0
        border.color: root.highlightColor
    }
}
