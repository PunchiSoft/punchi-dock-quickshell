// SPDX-License-Identifier: GPL-3.0-or-later
// Wave geometry adapted from Punchi Dock Remastered's DockItem.qml.
import QtQuick

QtObject {
    id: root

    property bool active: false
    property bool enabled: true
    property bool reducedMotion: false
    property real pointerX: 0
    property real itemPitch: 72
    property real iconSize: 40
    property real maximumScale: 1.65
    property real sharedScaleLimit: 0.5
    property int activeIndex: -1
    property int enterDuration: 110
    property int leaveDuration: 85
    property real progress: active && enabled ? 1 : 0
    readonly property real sharedDelta: Math.min(Math.max(0, sharedScaleLimit), Math.max(0, maximumScale - 1))
    readonly property real primaryDelta: Math.max(0, maximumScale - 1 - sharedDelta)
    readonly property real radius: Math.max(iconSize * 3, itemPitch * 2.75)
    readonly property real maximumShift: iconSize * sharedDelta * radius / (2 * itemPitch)

    Behavior on progress {
        enabled: !root.reducedMotion
        NumberAnimation {
            duration: root.active ? root.enterDuration : root.leaveDuration
            easing.type: root.active ? Easing.OutCubic : Easing.InQuad
        }
    }

    function scaleAt(centerX: real, index: int): real {
        if (!root.enabled || root.progress <= 0 || !Number.isFinite(root.pointerX)
                || !Number.isFinite(root.maximumScale) || root.itemPitch <= 0)
            return 1
        if (root.reducedMotion)
            return root.active && index === root.activeIndex
                ? 1 + Math.min(0.08, Math.max(0, root.maximumScale - 1) * 0.25) : 1
        const distance = Math.abs(centerX - root.pointerX)
        if (distance >= root.radius)
            return 1
        const influence = 0.5 * (1 + Math.cos(Math.PI * distance / root.radius))
        let scale = 1 + root.sharedDelta * influence * root.progress
        const primaryRadius = root.itemPitch * 0.5
        if (root.primaryDelta > 0 && distance < primaryRadius) {
            const peak = 0.5 * (1 + Math.cos(Math.PI * distance / primaryRadius))
            scale += root.primaryDelta * peak * root.progress
        }
        return scale
    }

    function shiftAt(centerX: real): real {
        if (!root.enabled || root.reducedMotion || root.progress <= 0
                || !Number.isFinite(root.pointerX) || root.itemPitch <= 0)
            return 0
        const signedDistance = centerX - root.pointerX
        if (Math.abs(signedDistance) < 0.001)
            return 0
        const distance = Math.min(1, Math.abs(signedDistance) / root.radius)
        const integrated = root.radius * (0.5 * distance
            + Math.sin(Math.PI * distance) / (2 * Math.PI))
        const shift = root.iconSize * root.sharedDelta * root.progress * integrated / root.itemPitch
        return signedDistance < 0 ? -shift : shift
    }
}
