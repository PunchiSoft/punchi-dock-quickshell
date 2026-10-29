// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"

PunchiSettingsCard {
    id: root
    required property PunchiShellSettings settings

    objectName: "dockMotionCard"
    Layout.fillWidth: true
    title: qsTr("Animations")
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Click bounce")
        showSeparator: true
        Switch {
            objectName: "bounceEnabled"
            Accessible.name: qsTr("Click bounce")
            checked: root.settings.bounceEnabled
            onToggled: root.settings.bounceEnabled = checked
        }
    }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Reduced motion")
        showSeparator: false
        Switch {
            objectName: "reducedMotion"
            Accessible.name: qsTr("Reduced motion")
            checked: root.settings.reducedMotion
            onToggled: root.settings.reducedMotion = checked
        }
    }
}
