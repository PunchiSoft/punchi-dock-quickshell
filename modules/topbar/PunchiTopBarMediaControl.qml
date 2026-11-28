// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Now playing: the selected session player, its announced track text and only
// the transport actions that player reports. The section disappears when no
// player exists, so the quick controls do not reserve empty space.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarMediaControl"
    visible: root.control !== null && root.control.available === true
    spacing: Kirigami.Units.smallSpacing
    function focusFirst(): void { playPause.forceActiveFocus(Qt.PopupFocusReason) }
    PunchiTopBarControlRow {
        iconName: "audio-x-generic"
        title: root.control ? root.control.title : ""
        statusText: root.control ? root.control.statusText : ""
        ToolButton {
            id: previous
            objectName: "topBarMediaPrevious"
            icon.name: "media-skip-backward"
            Accessible.name: qsTr("Previous track")
            enabled: root.control && root.control.canPrevious
            onClicked: if (root.control) root.control.dispatch("previous")
        }
        ToolButton {
            id: playPause
            objectName: "topBarMediaPlayPause"
            icon.name: root.control && root.control.playing
                ? "media-playback-pause" : "media-playback-start"
            Accessible.name: root.control && root.control.playing
                ? qsTr("Pause") : qsTr("Play")
            enabled: root.control && root.control.canPlayPause
            onClicked: if (root.control) root.control.dispatch("play-pause")
        }
        ToolButton {
            id: next
            objectName: "topBarMediaNext"
            icon.name: "media-skip-forward"
            Accessible.name: qsTr("Next track")
            enabled: root.control && root.control.canNext
            onClicked: if (root.control) root.control.dispatch("next")
        }
    }
}
