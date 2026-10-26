// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"

ColumnLayout {
    id: root
    objectName: "settingsDockPopups"
    required property ShellSettings settings
    function focusFirst(): void { popupScaleControl.focusControl() }
    spacing: Kirigami.Units.largeSpacing
    SettingsCard {
        objectName: "dockPopupsCard"
        Layout.fillWidth: true
        title: qsTr("Popups")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            GridLayout {
                objectName: "popupScaleLayout"
                Layout.fillWidth: true
                columns: width >= Kirigami.Units.gridUnit * 26 ? 2 : 1
                columnSpacing: Kirigami.Units.largeSpacing * 2
                rowSpacing: Kirigami.Units.largeSpacing
                SettingsScaleControl {
                    id: popupScaleControl
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    title: qsTr("Popup size")
                    minimumText: qsTr("Small")
                    maximumText: qsTr("Large")
                    controlName: "popupScale"
                    from: 80; to: 130; stepSize: 5
                    value: Math.round(root.settings.popupScale * 100)
                    onMoved: function(value) { root.settings.popupScale = value / 100 }
                }
                SettingsScaleControl {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    title: qsTr("Popup height")
                    minimumText: qsTr("Short")
                    maximumText: qsTr("Tall")
                    controlName: "popupHeight"
                    from: 40; to: 90; stepSize: 5
                    value: root.settings.popupHeightPercent
                    onMoved: function(value) { root.settings.popupHeightPercent = Math.round(value) }
                }
            }
        }
    }
    // One glyph per presentation: fan rows sit 1.33 icons apart, so a size that
    // reads well in the grid crowds the arc.
    SettingsCard {
        objectName: "dockPopupIconsCard"
        Layout.fillWidth: true
        title: qsTr("Icon size")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            SettingsIconSizeControl {
                id: gridIconControl
                Layout.fillWidth: true
                title: qsTr("Grid")
                controlName: "popupIconSize"
                from: root.settings.popupIconSizeMinimum
                to: root.settings.popupGridIconSizeMaximum
                value: root.settings.popupIconSize > 0
                    ? root.settings.popupIconSize : Kirigami.Units.iconSizes.large
                onMoved: function(value) { root.settings.popupIconSize = Math.round(value) }
            }
            SettingsSeparator { Layout.fillWidth: true }
            SettingsIconSizeControl {
                Layout.fillWidth: true
                title: qsTr("List and detail")
                controlName: "popupListIconSize"
                from: root.settings.popupIconSizeMinimum
                to: root.settings.popupListIconSizeMaximum
                value: root.settings.popupListIconSize > 0
                    ? root.settings.popupListIconSize : Kirigami.Units.iconSizes.medium
                onMoved: function(value) { root.settings.popupListIconSize = Math.round(value) }
            }
            SettingsSeparator { Layout.fillWidth: true }
            SettingsIconSizeControl {
                Layout.fillWidth: true
                title: qsTr("Fan")
                controlName: "popupFanIconSize"
                from: root.settings.popupIconSizeMinimum
                to: root.settings.popupFanIconSizeMaximum
                value: root.settings.popupFanIconSize > 0
                    ? root.settings.popupFanIconSize : Kirigami.Units.iconSizes.large
                onMoved: function(value) { root.settings.popupFanIconSize = Math.round(value) }
            }
        }
    }
}
