// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../config"

// Optional top panel switch. The card edits the settings draft, so Apply,
// Accept, Close and Escape keep the behaviour of every other General row.
PunchiSettingsCard {
    id: root
    required property PunchiShellSettings settings
    objectName: "topBarCard"
    Layout.fillWidth: true
    title: qsTr("Top panel")
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Show top panel")
        showSeparator: false
        Switch {
            objectName: "topBarEnabled"
            Accessible.name: qsTr("Show top panel")
            checked: root.settings.topBarEnabled
            onCheckedChanged: root.settings.topBarEnabled = checked
        }
    }
}
