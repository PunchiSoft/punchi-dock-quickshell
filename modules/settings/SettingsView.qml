// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"

Pane {
    id: root
    objectName: "dockSettingsView"
    required property ShellSettings settings
    property var applicationCatalog: null
    property int currentPage: 1
    property bool hasPendingChanges: false
    readonly property bool addingApplication: addDialog.visible
    signal applyRequested()
    signal acceptRequested()
    signal closeRequested()
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    palette.window: Kirigami.Theme.backgroundColor
    palette.windowText: Kirigami.Theme.textColor
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.largeSpacing * 2
    implicitWidth: Kirigami.Units.gridUnit * 40
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 32, generalPage.implicitHeight + padding * 2 + footer.implicitHeight)
    function focusFirst(): void {
        if (currentPage === 0) itemsPage.focusFirst()
        else generalPage.focusFirst()
    }
    function closeDialogs(): void { addDialog.close(); pinService.cancel() }
    ApplicationPinService { id: pinService; settings: root.settings; catalog: root.applicationCatalog }
    AddApplicationDialog {
        id: addDialog
        controller: pinService
        hostItem: root
        onSearchRequested: function(text) { pinService.search(text) }
        onSelectionRequested: function(appId) { pinService.select(appId) }
        onAddRequested: if (pinService.accept()) close()
        onClosed: { pinService.cancel(); itemsPage.focusFirst() }
    }
    ButtonGroup { id: navigation }
    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing
        Pane {
            objectName: "settingsSidebar"
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 8
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            Layout.maximumWidth: Kirigami.Units.gridUnit * 8
            padding: Kirigami.Units.smallSpacing
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            background: Rectangle { color: Kirigami.Theme.backgroundColor }
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                ItemDelegate {
                    objectName: "itemsSettingsPage"
                    Layout.fillWidth: true
                    text: qsTr("Items")
                    icon.name: "view-list-icons"
                    checkable: true
                    checked: root.currentPage === 0
                    highlighted: checked
                    ButtonGroup.group: navigation
                    onClicked: { root.currentPage = 0; itemsPage.focusFirst() }
                }
                ItemDelegate {
                    objectName: "generalSettingsPage"
                    Layout.fillWidth: true
                    text: qsTr("General")
                    icon.name: "preferences-system"
                    checkable: true
                    checked: root.currentPage === 1
                    highlighted: checked
                    ButtonGroup.group: navigation
                    onClicked: { root.currentPage = 1; generalPage.focusFirst() }
                }
                Item { Layout.fillHeight: true }
            }
        }
        ColumnLayout {
            objectName: "settingsMainContent"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage
                DockItemsSettings {
                    id: itemsPage
                    settings: root.settings
                    applicationCatalog: root.applicationCatalog
                    onAddRequested: { pinService.begin(); addDialog.open() }
                }
                DockGeneralSettings { id: generalPage; settings: root.settings }
            }
            RowLayout {
                id: footer
                Layout.fillWidth: true
                Button { objectName: "resetDockSettings"; text: qsTr("Reset defaults"); onClicked: root.settings.reset() }
                Item { Layout.fillWidth: true }
                Button {
                    objectName: "applyDockSettings"
                    text: qsTr("Apply")
                    enabled: root.hasPendingChanges
                    onClicked: root.applyRequested()
                }
                Button { objectName: "acceptDockSettings"; text: qsTr("Accept"); onClicked: root.acceptRequested() }
                Button { objectName: "closeDockSettings"; text: qsTr("Close"); onClicked: root.closeRequested() }
            }
        }
    }
}
