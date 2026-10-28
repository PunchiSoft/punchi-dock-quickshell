// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property bool motionEnabled: true
    property bool pointerEmphasis: true
    property var media: null
    readonly property bool available: media !== null && media.available
    signal commandRequested(string command)
    spacing: 0
    implicitWidth: Math.max(previous.implicitWidth, playPause.implicitWidth, next.implicitWidth, stop.implicitWidth)
    DockContextAction {
        pointerEmphasis: root.pointerEmphasis
        id: previous
        motionEnabled: root.motionEnabled
        objectName: "mediaPreviousAction"
        Layout.fillWidth: true
        text: qsTr("Previous Track")
        icon.name: "media-skip-backward"
        enabled: root.available && root.media.canPrevious
        onClicked: root.commandRequested("previous")
    }
    DockContextAction {
        pointerEmphasis: root.pointerEmphasis
        id: playPause
        motionEnabled: root.motionEnabled
        objectName: "mediaPlayPauseAction"
        Layout.fillWidth: true
        text: root.available && root.media.playing ? qsTr("Pause") : qsTr("Play")
        icon.name: root.available && root.media.playing ? "media-playback-pause" : "media-playback-start"
        enabled: root.available && root.media.canPlayPause
        onClicked: root.commandRequested("play-pause")
    }
    DockContextAction {
        pointerEmphasis: root.pointerEmphasis
        id: next
        motionEnabled: root.motionEnabled
        objectName: "mediaNextAction"
        Layout.fillWidth: true
        text: qsTr("Next Track")
        icon.name: "media-skip-forward"
        enabled: root.available && root.media.canNext
        onClicked: root.commandRequested("next")
    }
    DockContextAction {
        pointerEmphasis: root.pointerEmphasis
        id: stop
        motionEnabled: root.motionEnabled
        objectName: "mediaStopAction"
        Layout.fillWidth: true
        text: qsTr("Stop")
        icon.name: "media-playback-stop"
        enabled: root.available && root.media.canStop
        onClicked: root.commandRequested("stop")
    }
    DockContextSeparator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }
}
