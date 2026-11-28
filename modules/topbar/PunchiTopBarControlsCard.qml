// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Quick controls card: volume, Wi-Fi, Bluetooth and removable storage, plus the
// KDE settings modules that own configuration Punchi does not implement. The
// card scrolls inside the popup instead of growing past the screen edge.
ColumnLayout {
    id: root
    property var controls: null
    property real maximumHeight: Kirigami.Units.gridUnit * 24
    property bool reducedMotion: false
    signal settingsRequested(string module)
    signal bluetoothPairingRequested()
    objectName: "topBarControlsCard"
    spacing: Kirigami.Units.smallSpacing
    implicitHeight: flick.implicitHeight
    function focusFirst(): void {
        if (brightness.ready) brightness.focusFirst()
        else if (volume) volume.focusFirst()
    }
    Flickable {
        id: flick
        objectName: "topBarControlsFlickable"
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        implicitHeight: Math.min(body.implicitHeight, root.maximumHeight)
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            objectName: "topBarControlsBody"
            width: flick.width
            spacing: Kirigami.Units.smallSpacing
            PunchiTopBarBrightnessControl {
                id: brightness
                Layout.fillWidth: true
                control: root.controls ? root.controls.brightness : null
            }
            PunchiTopBarSeparator {}
            PunchiTopBarVolumeControl {
                id: volume
                Layout.fillWidth: true
                control: root.controls ? root.controls.audio : null
            }
            PunchiTopBarSeparator {}
            PunchiTopBarMediaControl {
                id: media
                Layout.fillWidth: true
                control: root.controls ? root.controls.media : null
            }
            PunchiTopBarSeparator { visible: media.visible }
            PunchiTopBarWifiControl {
                Layout.fillWidth: true
                control: root.controls ? root.controls.network : null
            }
            PunchiTopBarSeparator {}
            PunchiTopBarBluetoothControl {
                Layout.fillWidth: true
                control: root.controls ? root.controls.bluetooth : null
                onPairRequested: root.bluetoothPairingRequested()
            }
            PunchiTopBarSeparator {}
            PunchiTopBarStorageControl {
                Layout.fillWidth: true
                control: root.controls ? root.controls.storage : null
            }
            GridLayout {
                objectName: "topBarSettingsLinks"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 0
                Repeater {
                    model: [
                        {key: "network", label: qsTr("Network settings")},
                        {key: "bluetooth", label: qsTr("Bluetooth settings")},
                        {key: "audio", label: qsTr("Sound settings")},
                        {key: "storage", label: qsTr("Removable devices")}
                    ]
                    delegate: ToolButton {
                        required property var modelData
                        text: modelData.label
                        font: Kirigami.Theme.smallFont
                        leftPadding: 0
                        rightPadding: 0
                        Accessible.name: modelData.label
                        onClicked: root.settingsRequested(modelData.key)
                    }
                }
            }
        }
    }
}
