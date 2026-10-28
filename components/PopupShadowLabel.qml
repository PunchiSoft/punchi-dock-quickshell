// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// Shared 25% theme-aware text shadow for popup captions and titles.
Label {
    id: root
    readonly property real shadowAmount: 0.25
    readonly property real shadowBlur: Math.max(0.15, shadowAmount)
    readonly property real shadowOpacity: 0.45 + 0.45 * shadowAmount
    readonly property real shadowOffset: 0.5 * shadowAmount
    readonly property bool shadowAvailable: GraphicsInfo.api !== GraphicsInfo.Software

    color: Kirigami.Theme.textColor
    layer.enabled: root.shadowAvailable && root.visible && root.opacity > 0.001
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.color
        blurMax: 5
        shadowBlur: root.shadowBlur
        shadowOpacity: root.shadowOpacity
        shadowHorizontalOffset: root.shadowOffset
        shadowVerticalOffset: root.shadowOffset
    }
}
