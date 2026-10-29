// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PunchiPanelModes.js" as PunchiPanelModes

PunchiSettingsCard {
    id: root
    required property PunchiShellSettings settings
    function focusVisibility(): void { visibilityControl.forceActiveFocus() }

    objectName: "dockAppearanceCard"
    Layout.fillWidth: true
    title: qsTr("Dock")
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        GridLayout {
            objectName: "settingsScaleLayout"
            Layout.fillWidth: true
            columns: width >= Kirigami.Units.gridUnit * 26 ? 2 : 1
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.largeSpacing
            PunchiSettingsScaleControl {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                title: qsTr("Size")
                minimumText: qsTr("Small")
                maximumText: qsTr("Large")
                controlName: "iconSize"
                from: 50; to: 150; stepSize: 5
                value: root.settings.sizePercent
                onMoved: function(value) { root.settings.sizePercent = Math.round(value) }
            }
            PunchiSettingsScaleControl {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                title: qsTr("Magnification")
                minimumText: qsTr("No")
                nearMinimumText: qsTr("Small")
                maximumText: qsTr("Large")
                controlName: "zoomScale"
                from: 100; to: 300; stepSize: 10
                value: root.settings.magnificationEnabled ? root.settings.maximumIconScale * 100 : 100
                onMoved: function(value) {
                    root.settings.maximumIconScale = value / 100
                    root.settings.magnificationEnabled = value > 100
                }
            }
        }
    }
    PunchiSettingsSeparator { Layout.fillWidth: true }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Position on screen")
        showSeparator: true
        ComboBox {
            objectName: "dockPosition"
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            model: [qsTr("Bottom"), qsTr("Left"), qsTr("Right")]
            currentIndex: ["bottom", "left", "right"].indexOf(root.settings.dockEdge)
            Accessible.name: qsTr("Position on screen")
            onActivated: root.settings.dockEdge = ["bottom", "left", "right"][currentIndex]
        }
    }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Visibility")
        showSeparator: true
        ComboBox {
            id: visibilityControl
            objectName: "visibilityMode"
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            model: [qsTr("Always visible"), qsTr("Hide automatically"), qsTr("Dodge windows"), qsTr("Windows go below")]
            currentIndex: PunchiPanelModes.modes.indexOf(PunchiPanelModes.effective(root.settings.panelMode))
            Accessible.name: qsTr("Visibility")
            onActivated: root.settings.panelMode = PunchiPanelModes.modes[currentIndex]
        }
    }
}
