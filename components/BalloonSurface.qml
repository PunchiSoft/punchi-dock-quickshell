// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

AntialiasedSurface {
    id: root
    property color fillColor: Kirigami.Theme.backgroundColor
    property color strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.2)
    property real borderWidth: Kirigami.Units.smallSpacing / 4
    property real cornerRadius: Kirigami.Units.cornerRadius * 2
    property real tailHeight: Kirigami.Units.largeSpacing
    property real pointerX: width / 2
    readonly property real bodyHeight: height - tailHeight
    readonly property real radius: Math.min(cornerRadius, bodyHeight / 2, width / 2)
    readonly property real strokeInset: borderWidth / 2
    readonly property real pointerCenter: Math.max(radius + tailHeight,
        Math.min(width - radius - tailHeight, pointerX))

    // One continuous outline: the pointer shares the body fill and border.
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: root.borderWidth
            strokeColor: root.strokeColor
            fillColor: root.fillColor
            startX: root.radius
            startY: root.strokeInset
            PathLine { x: root.width - root.radius; y: root.strokeInset }
            PathQuad { x: root.width - root.strokeInset; y: root.radius; controlX: root.width - root.strokeInset; controlY: root.strokeInset }
            PathLine { x: root.width - root.strokeInset; y: root.bodyHeight - root.radius }
            PathQuad { x: root.width - root.radius; y: root.bodyHeight; controlX: root.width - root.strokeInset; controlY: root.bodyHeight }
            PathLine { x: root.pointerCenter + root.tailHeight; y: root.bodyHeight }
            PathLine { x: root.pointerCenter; y: root.height - root.strokeInset }
            PathLine { x: root.pointerCenter - root.tailHeight; y: root.bodyHeight }
            PathLine { x: root.radius; y: root.bodyHeight }
            PathQuad { x: root.strokeInset; y: root.bodyHeight - root.radius; controlX: root.strokeInset; controlY: root.bodyHeight }
            PathLine { x: root.strokeInset; y: root.radius }
            PathQuad { x: root.radius; y: root.strokeInset; controlX: root.strokeInset; controlY: root.strokeInset }
        }
    }
}
