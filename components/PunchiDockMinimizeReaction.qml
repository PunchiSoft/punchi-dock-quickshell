// SPDX-License-Identifier: GPL-3.0-or-later
// Minimize reaction adapted from Punchi Dock Remastered's MinimizeItemReaction.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string mode: "none"
    property int itemIndex: -1
    property int targetIndex: -1
    property int revision: 0
    property int iconSize: 48
    property bool vertical: false
    property bool motionEnabled: true
    property real bounceDirection: -1
    property real displacement: 0

    readonly property int indexDistance: Math.abs(itemIndex - targetIndex)
    readonly property bool bounceAlongHorizontalAxis: vertical
    readonly property real rippleDirection: itemIndex < targetIndex ? -1 : 1
    readonly property real bounceAmplitude: Math.max(5, Math.round(iconSize * 0.18))
    readonly property real rippleAmplitude: Math.max(3,
        Math.round(iconSize * 0.15 * Math.max(0.32, 1 - indexDistance * 0.34)))
    readonly property real horizontalOffset: mode === "slowBounce"
        ? (bounceAlongHorizontalAxis ? displacement * bounceDirection : 0)
        : (mode === "lateralRipple" && !vertical ? displacement * rippleDirection : 0)
    readonly property real verticalOffset: mode === "slowBounce"
        ? (!bounceAlongHorizontalAxis ? displacement * bounceDirection : 0)
        : (mode === "lateralRipple" && vertical ? displacement * rippleDirection : 0)
    readonly property bool running: slowBounce.running || lateralRipple.running

    visible: false
    Accessible.ignored: true

    onRevisionChanged: play()
    onModeChanged: reset()
    onMotionEnabledChanged: if (!motionEnabled) reset()

    function reset(): void {
        slowBounce.stop()
        lateralRipple.stop()
        displacement = 0
    }

    function play(): void {
        reset()
        if (!motionEnabled || mode === "none" || itemIndex < 0 || targetIndex < 0
                || iconSize <= 0 || Kirigami.Units.longDuration <= 0) return
        if (mode === "slowBounce" && indexDistance === 0) slowBounce.restart()
        else if (mode === "lateralRipple" && indexDistance <= 2) lateralRipple.restart()
    }

    SequentialAnimation {
        id: slowBounce

        NumberAnimation {
            target: root
            property: "displacement"
            to: root.bounceAmplitude
            duration: Math.round(Kirigami.Units.longDuration * 0.7)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "displacement"
            to: -root.bounceAmplitude * 0.24
            duration: Math.round(Kirigami.Units.longDuration * 0.85)
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root
            property: "displacement"
            to: 0
            duration: Math.round(Kirigami.Units.longDuration * 0.75)
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation {
        id: lateralRipple

        PauseAnimation {
            duration: Math.round(root.indexDistance * Kirigami.Units.shortDuration * 0.45)
        }
        NumberAnimation {
            target: root
            property: "displacement"
            to: root.rippleAmplitude
            duration: Math.round(Kirigami.Units.shortDuration * 0.75)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "displacement"
            to: -root.rippleAmplitude * 0.45
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root
            property: "displacement"
            to: 0
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutBack
        }
    }
}
