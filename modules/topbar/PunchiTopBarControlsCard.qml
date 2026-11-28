// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Compact quick-controls card: connectivity and Do Not Disturb first, then
// brightness and volume bands, then media and removable storage only when their
// providers have content. Each group keeps the KDE settings access beside the
// control it configures; the card scrolls instead of growing past the screen.
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
        if (wifi.control && wifi.control.actionEnabled) wifi.focusFirst()
        else if (brightness.ready) brightness.focusFirst()
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
            GridLayout {
                objectName: "topBarConnectivitySection"
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                PunchiTopBarSection {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    PunchiTopBarWifiControl {
                        id: wifi
                        Layout.fillWidth: true
                        compact: true
                        control: root.controls ? root.controls.network : null
                        onSettingsRequested: root.settingsRequested("network")
                    }
                }
                PunchiTopBarSection {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    PunchiTopBarBluetoothControl {
                        Layout.fillWidth: true
                        compact: true
                        control: root.controls ? root.controls.bluetooth : null
                        onSettingsRequested: root.settingsRequested("bluetooth")
                        onPairRequested: root.bluetoothPairingRequested()
                    }
                }
            }
            PunchiTopBarSection {
                objectName: "topBarDndSection"
                Layout.fillWidth: true
                PunchiTopBarDoNotDisturbControl {
                    Layout.fillWidth: true
                    control: root.controls ? root.controls.dnd : null
                    onSettingsRequested: root.settingsRequested("notifications")
                }
            }
            PunchiTopBarSection {
                objectName: "topBarBrightnessSection"
                Layout.fillWidth: true
                PunchiTopBarBrightnessControl {
                    id: brightness
                    Layout.fillWidth: true
                    control: root.controls ? root.controls.brightness : null
                }
            }
            PunchiTopBarSection {
                objectName: "topBarVolumeSection"
                Layout.fillWidth: true
                PunchiTopBarVolumeControl {
                    id: volume
                    Layout.fillWidth: true
                    control: root.controls ? root.controls.audio : null
                    onSettingsRequested: root.settingsRequested("audio")
                }
            }
            PunchiTopBarSection {
                Layout.fillWidth: true
                visible: root.controls !== null && root.controls.media !== null
                    && root.controls.media.available === true
                PunchiTopBarMediaControl {
                    id: media
                    Layout.fillWidth: true
                    control: root.controls ? root.controls.media : null
                }
            }
            PunchiTopBarSection {
                Layout.fillWidth: true
                visible: root.controls !== null && root.controls.storage !== null
                    && root.controls.storage.devices.length > 0
                PunchiTopBarStorageControl {
                    id: storage
                    Layout.fillWidth: true
                    control: root.controls ? root.controls.storage : null
                    onSettingsRequested: root.settingsRequested("storage")
                }
            }
        }
    }
}
