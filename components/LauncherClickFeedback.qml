// SPDX-License-Identifier: GPL-3.0-or-later
// Bounce branch adapted from Punchi Dock Remastered's DockItemClickFeedback.
import QtQuick
import org.kde.kirigami as Kirigami
import "../config"

Item {
    id: root

    readonly property DockMetrics metrics: DockMetrics {}
    property int iconSize: metrics.iconSize
    property int duration: Kirigami.Units.longDuration
    property bool motionEnabled: true
    readonly property bool running: bounce.running
    readonly property real verticalOffset: -bounce.progress * iconSize * 0.45
    visible: false
    Accessible.ignored: true

    onMotionEnabledChanged: if (!motionEnabled) reset()
    onDurationChanged: reset()

    function reset() { bounce.reset() }
    function play() {
        // Coalesce feedback only; the caller still performs every activation.
        if (motionEnabled) bounce.play()
    }

    TwoHopBounce {
        id: bounce
        duration: root.duration
    }
}
