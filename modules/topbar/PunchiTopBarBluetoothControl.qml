// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Bluetooth radio switch. Adapter presence, power and the blocked state come
// from the provider; pairing and discovery stay in KDE.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarBluetoothControl"
    spacing: Kirigami.Units.smallSpacing
    signal pairRequested()
    function focusFirst(): void { toggle.forceActiveFocus(Qt.PopupFocusReason) }
    function syncChecked(): void {
        if (root.control) toggle.checked = root.control.powered
    }
    Component.onCompleted: syncChecked()
    onControlChanged: syncChecked()
    PunchiTopBarControlRow {
        iconName: root.control ? root.control.iconName : "network-bluetooth-inactive"
        title: qsTr("Bluetooth")
        statusText: root.control ? root.control.statusText : qsTr("Unavailable")
        statusActive: root.control !== null && root.control.powered
        ToolButton {
            objectName: "topBarBluetoothPair"
            text: qsTr("Pair")
            font: Kirigami.Theme.smallFont
            visible: root.control !== null && root.control.powered
            enabled: visible && !root.control.blocked
            Accessible.name: qsTr("Pair Bluetooth device")
            onClicked: root.pairRequested()
        }
        Switch {
            id: toggle
            objectName: "topBarBluetoothSwitch"
            Accessible.name: qsTr("Bluetooth")
            enabled: root.control !== null && root.control.actionEnabled
            onCheckedChanged: if (root.control && checked !== root.control.powered) root.control.setPowered(checked)
            readonly property Connections stateChanges: Connections {
                target: root.control
                function onPoweredChanged() { if (!toggle.pressed) toggle.checked = root.control.powered }
                function onPendingChanged() { if (!root.control.pending) toggle.checked = root.control.powered }
                function onErrorCodeChanged() { toggle.checked = root.control.powered }
            }
        }
    }
}
