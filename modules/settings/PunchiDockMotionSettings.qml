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
        text: qsTr("Minimize reaction")
        showSeparator: true
        ComboBox {
            objectName: "windowMinimizeReaction"
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            model: [qsTr("None"), qsTr("Slow bounce"), qsTr("Lateral ripple")]
            currentIndex: ["none", "slowBounce", "lateralRipple"]
                .indexOf(root.settings.windowMinimizeReaction)
            Accessible.name: qsTr("Minimize reaction")
            onActivated: root.settings.windowMinimizeReaction
                = ["none", "slowBounce", "lateralRipple"][currentIndex]
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
