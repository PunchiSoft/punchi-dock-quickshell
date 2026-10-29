// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

// Full-screen wash behind the menu grid. The wash keeps the original floor of
// 0.50 opacity so the desk never shows through enough to hurt legibility, and
// the blur covers the whole window as one rectangle. When KWin cannot blur, the
// surface keeps the theme color at the requested opacity, which stays readable.
Item {
    id: root

    property bool active: false
    property bool blurEnabled: true
    property real backgroundOpacity: 0.6
    property bool motionEnabled: true
    property int openDuration: Math.round(Kirigami.Units.longDuration * 1.1)
    property int closeDuration: Math.round(Kirigami.Units.shortDuration * 1.4)

    readonly property real safeOpacity: {
        const requested = Number(root.backgroundOpacity)
        return Number.isFinite(requested) ? Math.max(0.50, Math.min(1.0, requested)) : 0.6
    }
    readonly property bool blurred: blur.enabled && blur.available

    signal clicked()

    anchors.fill: parent
    opacity: root.active ? 1.0 : 0.0
    Accessible.ignored: true

    // A rectangle over the whole window: no tail and no radius, so the existing
    // popup controller needs no second code path for the fullscreen case.
    Native.PopupBlurController {
        id: blur
        window: root.Window.window
        geometry: Qt.rect(0, 0, root.width, root.height)
        tailEdge: "bottom"
        tailExtent: 0
        cornerRadius: 0
        enabled: root.active && root.blurEnabled
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: root.safeOpacity
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Behavior on opacity {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: root.active ? root.openDuration : root.closeDuration
            easing.type: root.active ? Easing.OutCubic : Easing.InQuad
        }
    }
}
