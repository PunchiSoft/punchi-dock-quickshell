// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "../config"

ToolTip {
    id: root
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window

    property string tailEdge: "bottom"
    readonly property bool verticalTail: tailEdge === "left" || tailEdge === "right"
    readonly property PunchiTooltipStyle metrics: PunchiTooltipStyle {}
    readonly property real strokeInset: metrics.borderWidth / 2
    readonly property real bodyHeight: verticalTail ? height : height - metrics.tailHeight
    readonly property real radius: Math.min(metrics.cornerRadius, bodyHeight / 2, width / 2)
    FontMetrics { id: labelMetrics; font: root.font }
    implicitWidth: Math.ceil(labelMetrics.advanceWidth(text)) + leftPadding + rightPadding
    implicitHeight: Math.ceil(labelMetrics.height) + metrics.padding * 2 + (verticalTail ? 0 : metrics.tailHeight)
    padding: metrics.padding
    bottomPadding: metrics.padding + (verticalTail ? 0 : metrics.tailHeight)
    leftPadding: metrics.padding + (tailEdge === "left" ? metrics.tailHeight : 0)
    rightPadding: metrics.padding + (tailEdge === "right" ? metrics.tailHeight : 0)
    delay: 350
    timeout: -1
    focus: false
    closePolicy: Popup.NoAutoClose

    contentItem: Label {
        text: root.text
        font: root.font
        color: root.Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
    }

    background: PunchiBalloonSurface {
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        borderWidth: root.metrics.borderWidth
        cornerRadius: root.metrics.cornerRadius
        tailHeight: root.metrics.tailHeight
        tailEdge: root.tailEdge
    }
}
