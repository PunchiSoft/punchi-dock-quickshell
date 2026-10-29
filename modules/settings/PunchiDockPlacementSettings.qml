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
    property var screens: []
    property string primaryScreenName: ""
    property var runningApplications: null
    // Injected by the page, which owns the selection rules.
    required property var disconnectedScreenKeys
    required property string fallbackScreenKey
    required property bool screenPlacementVisible
    function selectionWith(list, key, selected): var {
        const next = (Array.isArray(list) ? list : []).filter(entry => entry !== key)
        if (selected && next.length < 16) next.push(key)
        return next
    }
    function setScreenSelected(key: string, selected: bool): void {
        root.settings.selectedScreens = selectionWith(root.settings.selectedScreens, key, selected)
    }
    // While the saved screens are unplugged, checking one of the connected
    // screens is an explicit move, not an addition to an unusable selection.
    function setScreenChecked(key: string, selected: bool): void {
        if (selected && root.fallbackScreenKey.length > 0) {
            root.settings.selectedScreens = [key]
            return
        }
        root.setScreenSelected(key, selected)
    }
    function setDesktopSelected(key: string, selected: bool): void {
        root.settings.selectedDesktops = selectionWith(root.settings.selectedDesktops, key, selected)
    }
    function setActivitySelected(key: string, selected: bool): void {
        root.settings.selectedActivities = selectionWith(root.settings.selectedActivities, key, selected)
    }

    objectName: "dockPlacementCard"
    Layout.fillWidth: true
    title: qsTr("Screens and desktops")
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        PunchiSettingsRow {
            objectName: "screenPlacementRow"
            Layout.fillWidth: true
            visible: root.screenPlacementVisible
            text: qsTr("Show dock on")
            showSeparator: root.settings.screenMode !== "selected"
            ComboBox {
                objectName: "screenMode"
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                model: [qsTr("All screens"), qsTr("Selected screens")]
                currentIndex: root.settings.screenMode === "selected" ? 1 : 0
                Accessible.name: qsTr("Show dock on")
                onActivated: root.settings.screenMode = currentIndex === 1 ? "selected" : "all"
            }
        }
        ColumnLayout {
            objectName: "screenSelection"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.screenPlacementVisible
                && root.settings.screenMode === "selected"
            spacing: 0
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: qsTr("Screens")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Accessible.ignored: true
            }
            Repeater {
                model: root.screens
                delegate: CheckBox {
                    required property var modelData
                    objectName: "screen-" + modelData.name
                    Layout.fillWidth: true
                    text: ((modelData.model || "").length > 0
                        ? modelData.name + " · " + modelData.model
                        : modelData.name)
                        + (root.fallbackScreenKey === modelData.name
                            ? " · " + qsTr("Fallback") : "")
                    checked: (root.settings.selectedScreens || []).indexOf(modelData.name) >= 0
                    Accessible.name: text
                    // Click only: a fallback marker changes `checked` through the
                    // binding and must not rewrite the saved selection.
                    onClicked: root.setScreenChecked(modelData.name, checked)
                }
            }
            Repeater {
                model: root.disconnectedScreenKeys
                delegate: CheckBox {
                    required property string modelData
                    objectName: "screenMissing-" + modelData
                    Layout.fillWidth: true
                    checked: true
                    enabled: false
                    text: modelData + " · " + qsTr("Not connected")
                    Accessible.name: text
                }
            }
        }
        PunchiSettingsSeparator {
            objectName: "screenPlacementSeparator"
            Layout.fillWidth: true
            visible: root.screenPlacementVisible
                && root.settings.screenMode === "selected"
        }
        PunchiSettingsRow {
            Layout.fillWidth: true
            visible: root.runningApplications !== null && root.runningApplications.available
            text: qsTr("Virtual desktops")
            showSeparator: root.settings.desktopMode !== "selected"
            ComboBox {
                objectName: "desktopMode"
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                model: [qsTr("All desktops"), qsTr("Selected desktops")]
                currentIndex: root.settings.desktopMode === "selected" ? 1 : 0
                Accessible.name: qsTr("Virtual desktops")
                onActivated: root.settings.desktopMode = currentIndex === 1 ? "selected" : "all"
            }
        }
        ColumnLayout {
            objectName: "desktopSelection"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.settings.desktopMode === "selected"
                && root.runningApplications !== null && root.runningApplications.available
            spacing: 0
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: qsTr("Desktops")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Accessible.ignored: true
            }
            Repeater {
                model: root.runningApplications ? root.runningApplications.virtualDesktops : []
                delegate: CheckBox {
                    required property var modelData
                    objectName: "desktop-" + modelData.id
                    Layout.fillWidth: true
                    text: (modelData.name || "").length > 0
                        ? modelData.name : String(modelData.id)
                    checked: (root.settings.selectedDesktops || []).indexOf(String(modelData.id)) >= 0
                    Accessible.name: text
                    onCheckedChanged: root.setDesktopSelected(String(modelData.id), checked)
                }
            }
        }
        PunchiSettingsSeparator {
            Layout.fillWidth: true
            visible: root.settings.desktopMode === "selected"
                && root.runningApplications !== null && root.runningApplications.available
        }
        PunchiSettingsRow {
            Layout.fillWidth: true
            visible: root.runningApplications !== null && root.runningApplications.available
            text: qsTr("Activities")
            showSeparator: root.settings.activityMode !== "selected"
            ComboBox {
                objectName: "activityMode"
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                model: [qsTr("All activities"), qsTr("Selected activities")]
                currentIndex: root.settings.activityMode === "selected" ? 1 : 0
                Accessible.name: qsTr("Activities")
                onActivated: root.settings.activityMode = currentIndex === 1 ? "selected" : "all"
            }
        }
        ColumnLayout {
            objectName: "activitySelection"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing * 2
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.settings.activityMode === "selected"
                && root.runningApplications !== null && root.runningApplications.available
            spacing: 0
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: qsTr("Activities")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                Accessible.ignored: true
            }
            Repeater {
                model: root.runningApplications ? root.runningApplications.activities : []
                delegate: CheckBox {
                    required property var modelData
                    objectName: "activity-" + modelData.id
                    Layout.fillWidth: true
                    text: (modelData.name || "").length > 0
                        ? modelData.name : String(modelData.id)
                    checked: (root.settings.selectedActivities || []).indexOf(String(modelData.id)) >= 0
                    Accessible.name: text
                    onCheckedChanged: root.setActivitySelected(String(modelData.id), checked)
                }
            }
        }
        PunchiSettingsSeparator {
            Layout.fillWidth: true
            visible: root.settings.activityMode === "selected"
                && root.runningApplications !== null && root.runningApplications.available
        }
        PunchiSettingsRow {
            Layout.fillWidth: true
            text: qsTr("Running indicators follow the desktop")
            showSeparator: false
            Switch {
                objectName: "runningMarkersFollowDesktop"
                Accessible.name: qsTr("Running indicators follow the desktop")
                enabled: root.runningApplications !== null && root.runningApplications.available
                checked: root.settings.runningMarkersFollowDesktop
                onCheckedChanged: root.settings.runningMarkersFollowDesktop = checked
            }
        }
        PunchiSettingsRow {
            Layout.fillWidth: true
            text: qsTr("Keep the dock visible at a shared edge")
            showSeparator: false
            Switch {
                objectName: "avoidInnerEdgeAutoHide"
                Accessible.name: qsTr("Keep the dock visible at a shared edge")
                checked: root.settings.avoidInnerEdgeAutoHide
                onCheckedChanged: root.settings.avoidInnerEdgeAutoHide = checked
            }
        }
    }
}
