// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami

// Hover, selection and press surface of one menu cell, ported from the original
// menu so the dock conversation keeps the same four hover modes. The frame and
// its content share one scale, and reduced motion always settles at 1.0.
Rectangle {
    id: root

    property bool hovered: false
    property bool selected: false
    property bool pressed: false
    property bool motionEnabled: true
    property string animationMode: "pulse"
    property real motionScale: 1.0

    readonly property real visualScale: root.motionEnabled ? root.motionScale : 1.0

    readonly property NumberAnimation individualMotion: NumberAnimation {
        target: root
        property: "motionScale"
        to: 1.03
        duration: 130
        easing.type: Easing.OutCubic
    }
    readonly property NumberAnimation settleMotion: NumberAnimation {
        target: root
        property: "motionScale"
        to: 1.0
        duration: 100
        easing.type: Easing.OutCubic
    }
    readonly property SequentialAnimation pulseMotion: SequentialAnimation {
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.03
            duration: 95
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.0
            duration: 125
            easing.type: Easing.InOutCubic
        }
    }
    readonly property SequentialAnimation bounceMotion: SequentialAnimation {
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.03
            duration: 80
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 0.985
            duration: 70
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.012
            duration: 65
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.0
            duration: 80
            easing.type: Easing.OutCubic
        }
    }

    function stopAnimations(): void {
        root.individualMotion.stop()
        root.settleMotion.stop()
        root.pulseMotion.stop()
        root.bounceMotion.stop()
    }
    function updateHoverAnimation(): void {
        root.stopAnimations()
        if (!root.motionEnabled || root.animationMode === "none") {
            root.motionScale = 1.0
            return
        }
        if (!root.hovered) {
            root.settleMotion.restart()
            return
        }
        if (root.animationMode === "individual") root.individualMotion.restart()
        else if (root.animationMode === "bounce") root.bounceMotion.restart()
        else root.pulseMotion.restart()
    }

    color: root.selected || root.hovered
        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.20)
        : "transparent"
    border.color: root.selected ? Kirigami.Theme.highlightColor : "transparent"
    border.width: root.selected ? 2 : 0
    radius: Kirigami.Units.cornerRadius * 2
    scale: root.motionEnabled && root.pressed
        && root.animationMode !== "none" ? 0.97 : root.visualScale
    antialiasing: true
    Accessible.ignored: true

    onHoveredChanged: root.updateHoverAnimation()
    onAnimationModeChanged: root.updateHoverAnimation()
    onMotionEnabledChanged: root.updateHoverAnimation()

    Behavior on color {
        enabled: root.motionEnabled
        ColorAnimation { duration: Math.max(80, Math.min(140, Kirigami.Units.shortDuration)) }
    }
}
