// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Default audio sink: volume and mute. Values always come from the provider;
// dragging only forwards the intended value while the sink identity still
// matches the one captured when the gesture started.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarVolumeControl"
    signal settingsRequested()
    readonly property bool ready: root.control !== null && root.control.ready === true
    spacing: Kirigami.Units.smallSpacing
    function focusFirst(): void { slider.forceActiveFocus(Qt.PopupFocusReason) }
    PunchiTopBarControlRow {
        iconName: root.control ? root.control.iconName : "audio-volume-muted"
        title: qsTr("Volume")
        statusText: !root.control ? qsTr("Unavailable")
            : !root.control.ready ? qsTr("No audio output")
            : String(root.control.description || "")
        Label {
            objectName: "topBarVolumeValue"
            text: root.ready ? qsTr("%1%").arg(root.control.percent) : ""
            font: Kirigami.Theme.defaultFont
            color: Kirigami.Theme.textColor
        }
        ToolButton {
            objectName: "topBarVolumeSettings"
            icon.name: "settings-configure"
            Accessible.name: qsTr("Sound settings")
            onClicked: root.settingsRequested()
        }
        ToolButton {
            objectName: "topBarMute"
            enabled: root.ready
            Accessible.name: root.control && root.control.muted ? qsTr("Unmute") : qsTr("Mute")
            icon.name: root.control && root.control.muted ? "audio-volume-muted" : "audio-volume-high"
            icon.width: Kirigami.Units.iconSizes.smallMedium
            icon.height: Kirigami.Units.iconSizes.smallMedium
            onClicked: if (root.control) root.control.toggleMute()
        }
    }
    Slider {
        id: slider
        objectName: "topBarVolumeSlider"
        Layout.fillWidth: true
        enabled: root.ready
        from: 0
        to: root.control ? Math.max(1, root.control.maximumPercent) : 100
        stepSize: 1
        Accessible.name: qsTr("Volume")
        onMoved: if (root.control) root.control.setPercent(value)
        onPressedChanged: {
            if (!root.control) return
            if (pressed) root.control.beginGesture()
            else root.control.endGesture()
        }
    }
    readonly property Connections controlChanges: Connections {
        target: root.control
        function onPercentChanged() {
            if (!slider.pressed) slider.value = root.control.percent
        }
        function onMaximumPercentChanged() {
            if (!slider.pressed) slider.to = Math.max(1, root.control.maximumPercent)
        }
    }
    Component.onCompleted: {
        if (!root.control) return
        slider.value = root.control.percent
        slider.to = Math.max(1, root.control.maximumPercent)
    }
}
