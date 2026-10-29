// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PanelModes.js" as PanelModes

SettingsCard {
    id: root
    required property ShellSettings settings
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
            SettingsScaleControl {
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
            SettingsScaleControl {
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
    SettingsSeparator { Layout.fillWidth: true }
    SettingsRow {
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
    SettingsRow {
        Layout.fillWidth: true
        text: qsTr("Visibility")
        showSeparator: true
        ComboBox {
            id: visibilityControl
            objectName: "visibilityMode"
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            model: [qsTr("Always visible"), qsTr("Hide automatically"), qsTr("Dodge windows"), qsTr("Windows go below")]
            currentIndex: PanelModes.modes.indexOf(PanelModes.effective(root.settings.panelMode))
            Accessible.name: qsTr("Visibility")
            onActivated: root.settings.panelMode = PanelModes.modes[currentIndex]
        }
    }
}
