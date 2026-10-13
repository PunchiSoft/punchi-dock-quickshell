// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: root
    property bool requested: false
    property bool reducedMotion: false
    property int duration: Kirigami.Units.longDuration
    property bool present: false
    property real surfaceScale: 0.7
    property real surfaceOpacity: 0
    readonly property bool moving: entry.running || exit.running
    function settle(): void {
        entry.stop(); exit.stop()
        present = requested
        surfaceOpacity = requested ? 1 : 0
        surfaceScale = 1
    }
    function update(): void {
        entry.stop(); exit.stop()
        if (reducedMotion || duration <= 0) { settle(); return }
        if (requested) {
            if (!present) { surfaceScale = 0.7; surfaceOpacity = 0 }
            present = true
            entry.start()
        } else if (present) exit.start()
    }
    onRequestedChanged: update()
    onReducedMotionChanged: if (reducedMotion) settle()
    onDurationChanged: if (duration <= 0) settle()
    readonly property ParallelAnimation entry: ParallelAnimation {
        NumberAnimation {
            target: root; property: "surfaceScale"; to: 1
            duration: root.duration; easing.type: Easing.OutBack; easing.overshoot: 1.1
        }
        NumberAnimation {
            target: root; property: "surfaceOpacity"; to: 1
            duration: root.duration; easing.type: Easing.OutCubic
        }
    }
    readonly property ParallelAnimation exit: ParallelAnimation {
        NumberAnimation {
            target: root; property: "surfaceScale"; to: 0.9
            duration: root.duration; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "surfaceOpacity"; to: 0
            duration: root.duration; easing.type: Easing.InCubic
        }
        onFinished: if (!root.requested) root.present = false
    }
}
