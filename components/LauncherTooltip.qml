// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../config"

ToolTip {
    id: root

    readonly property TooltipStyle metrics: TooltipStyle {}
    readonly property real strokeInset: metrics.borderWidth / 2
    readonly property real bodyHeight: height - metrics.tailHeight
    readonly property real radius: Math.min(metrics.cornerRadius, bodyHeight / 2, width / 2)
    FontMetrics { id: labelMetrics; font: root.font }
    implicitWidth: Math.ceil(labelMetrics.advanceWidth(text)) + leftPadding + rightPadding
    implicitHeight: Math.ceil(labelMetrics.height) + metrics.padding * 2 + metrics.tailHeight
    padding: metrics.padding
    bottomPadding: metrics.padding + metrics.tailHeight
    delay: 350
    timeout: -1
    focus: false
    closePolicy: Popup.NoAutoClose

    contentItem: Label {
        text: root.text
        font: root.font
        color: root.palette.toolTipText
        horizontalAlignment: Text.AlignHCenter
    }

    background: BalloonSurface {
        fillColor: root.palette.toolTipBase
        strokeColor: root.palette.mid
        borderWidth: root.metrics.borderWidth
        cornerRadius: root.metrics.cornerRadius
        tailHeight: root.metrics.tailHeight
    }
}
