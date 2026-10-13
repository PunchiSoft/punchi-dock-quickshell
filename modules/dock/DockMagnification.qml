// SPDX-License-Identifier: GPL-3.0-or-later
// Continuous proximity wave, with exact spacing between scaled cells.
import QtQuick
import org.kde.kirigami as Kirigami
import "../../config"

QtObject {
    id: root

    property bool active: false
    property bool enabled: true
    property bool reducedMotion: false
    property real pointerX: 0
    readonly property DockMetrics metrics: DockMetrics {}
    property real itemPitch: itemSize + metrics.spacing
    property real iconSize: metrics.iconSize
    property real itemSize: iconSize + metrics.itemSize - metrics.iconSize
    property real maximumScale: 2
    property int activeIndex: -1
    property int enterDuration: Kirigami.Units.longDuration
    property int leaveDuration: Kirigami.Units.shortDuration
    property real progress: active && enabled ? 1 : 0
    readonly property bool validGeometry: Number.isFinite(itemPitch) && itemPitch > 0
        && Number.isFinite(iconSize) && iconSize > 0 && Number.isFinite(itemSize) && itemSize > 0
    readonly property real amplitude: Number.isFinite(maximumScale) ? Math.max(0, maximumScale - 1) : 0
    // Seven pitches across: three neighbours per side, including a soft shoulder.
    readonly property real radius: validGeometry ? itemPitch * 3.5 : 0
    readonly property real separationSize: validGeometry ? Math.max(iconSize, itemSize) : 0
    readonly property real maximumShift: separationSize * amplitude * 1.75

    Behavior on progress {
        enabled: !root.reducedMotion
        NumberAnimation {
            duration: root.active ? root.enterDuration : root.leaveDuration
            easing.type: root.active ? Easing.OutCubic : Easing.InQuad
        }
    }

    function scaleAt(centerX: real, index: int): real {
        if (!root.enabled || root.progress <= 0 || !Number.isFinite(root.pointerX)
                || !root.validGeometry)
            return 1
        if (root.reducedMotion)
            return root.active && index === root.activeIndex
                ? 1 + Math.min(0.08, root.amplitude * 0.25) : 1
        const distance = Math.abs(centerX - root.pointerX)
        if (distance >= root.radius)
            return 1
        const influence = 0.5 * (1 + Math.cos(Math.PI * distance / root.radius))
        return 1 + root.amplitude * influence * root.progress
    }

    // Sum compact cosine samples to the left in constant time. Endpoint samples
    // enter at zero with zero slope, preserving continuity as the cursor moves.
    function leftInfluenceSum(normalizedDistance: real): real {
        const first = Math.max(1, Math.floor(normalizedDistance - 3.5) + 1)
        const last = Math.ceil(normalizedDistance + 3.5) - 1
        if (last < first) return 0
        const count = last - first + 1
        const phase = Math.PI / 3.5
        const cosineSum = Math.sin(count * phase / 2) / Math.sin(phase / 2)
            * Math.cos(phase * (normalizedDistance - (first + last) / 2))
        return 0.5 * (count + cosineSum)
    }

    function shiftAt(centerX: real): real {
        if (!root.enabled || root.reducedMotion || root.progress <= 0
                || !Number.isFinite(root.pointerX) || !root.validGeometry)
            return 0
        const signedDistance = centerX - root.pointerX
        if (signedDistance === 0) return 0
        if (Math.abs(signedDistance) >= root.radius)
            return (signedDistance < 0 ? -1 : 1) * root.maximumShift * root.progress
        const distance = signedDistance / root.itemPitch
        // For adjacent cells, the shift difference equals half their combined
        // growth. Original gaps survive at every cursor position and zoom level.
        return root.separationSize * root.amplitude * root.progress * 0.5
            * (root.leftInfluenceSum(distance) - root.leftInfluenceSum(-distance))
    }
}
