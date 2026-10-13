// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property var media: null
    readonly property bool available: media !== null && media.available
    signal commandRequested(string command)
    spacing: 0
    implicitWidth: Math.max(previous.implicitWidth, playPause.implicitWidth, next.implicitWidth, stop.implicitWidth)
    DockContextAction {
        id: previous
        objectName: "mediaPreviousAction"
        Layout.fillWidth: true
        text: qsTr("Previous Track")
        icon.name: "media-skip-backward"
        enabled: root.available && root.media.canPrevious
        onClicked: root.commandRequested("previous")
    }
    DockContextAction {
        id: playPause
        objectName: "mediaPlayPauseAction"
        Layout.fillWidth: true
        text: root.available && root.media.playing ? qsTr("Pause") : qsTr("Play")
        icon.name: root.available && root.media.playing ? "media-playback-pause" : "media-playback-start"
        enabled: root.available && root.media.canPlayPause
        onClicked: root.commandRequested("play-pause")
    }
    DockContextAction {
        id: next
        objectName: "mediaNextAction"
        Layout.fillWidth: true
        text: qsTr("Next Track")
        icon.name: "media-skip-forward"
        enabled: root.available && root.media.canNext
        onClicked: root.commandRequested("next")
    }
    DockContextAction {
        id: stop
        objectName: "mediaStopAction"
        Layout.fillWidth: true
        text: qsTr("Stop")
        icon.name: "media-playback-stop"
        enabled: root.available && root.media.canStop
        onClicked: root.commandRequested("stop")
    }
    DockContextSeparator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }
}
