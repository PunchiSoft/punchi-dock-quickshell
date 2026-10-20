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
    property var autostart: null
    property var license: null
    property var recentApplications: null
    property int currentPage: 1
    property bool hasPendingChanges: false
    property bool aboutDialogOpen: false
    readonly property bool addingItem: itemsPage.addingItem
    signal applyRequested()
    signal acceptRequested()
    signal closeRequested()
    Shortcut {
        sequence: "Escape"
        enabled: root.addingItem
        onActivated: root.cancelAddingItem(true)
    }
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    palette.window: Kirigami.Theme.backgroundColor
    palette.windowText: Kirigami.Theme.textColor
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.largeSpacing * 2
    implicitWidth: Kirigami.Units.gridUnit * 54
    // Preserve enough preferred height for the unified item picker.
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 32,
        generalPage.implicitHeight + padding * 2 + footer.implicitHeight + Kirigami.Units.largeSpacing)
    function focusFirst(): void {
        if (currentPage === 0) itemsPage.focusFirst()
        else if (currentPage === 1) generalPage.focusFirst()
        else aboutPage.focusFirst()
    }
    function cancelAddingItem(restoreFocus: bool): void { itemsPage.cancelAddItem(restoreFocus) }
    function clearSelection(): void { itemsPage.clearSelection() }
    function ensureFocusedVisible(control: Item): void {
        if ((currentPage !== 1 && currentPage !== 2) || !control) return
        const page = currentPage === 1 ? generalPage : aboutPage
        let ancestor = control
        while (ancestor && ancestor !== page) ancestor = ancestor.parent
        if (!ancestor) return
        const viewport = currentPage === 1 ? generalViewport : aboutViewport
        if (!viewport) return
        const point = control.mapToItem(page, 0, 0)
        const margin = Kirigami.Units.mediumSpacing
        const maximum = Math.max(0, viewport.contentHeight - viewport.height)
        if (point.y - margin < viewport.contentY)
            viewport.contentY = Math.max(0, Math.min(maximum, point.y - margin))
        else if (point.y + control.height + margin > viewport.contentY + viewport.height)
            viewport.contentY = Math.max(0, Math.min(maximum, point.y + control.height + margin - viewport.height))
    }
    ApplicationPinService { id: pinService; settings: root.settings; catalog: root.applicationCatalog }
    ButtonGroup { id: navigation }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Pane {
            objectName: "settingsSidebar"
            Layout.fillHeight: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            padding: Kirigami.Units.smallSpacing
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            background: Rectangle {
                radius: Kirigami.Units.cornerRadius * 2
                color: Kirigami.Theme.alternateBackgroundColor
            }
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.mediumSpacing
                SettingsUserHeader {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                }
                SettingsCategoryButton {
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
                SettingsCategoryButton {
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
                SettingsCategoryButton {
                    objectName: "aboutSettingsPage"
                    Layout.fillWidth: true
                    text: qsTr("About")
                    icon.name: "help-about"
                    checkable: true
                    checked: root.currentPage === 2
                    highlighted: checked
                    ButtonGroup.group: navigation
                    onClicked: { root.currentPage = 2; aboutPage.focusFirst() }
                }
            }
        }
        Rectangle {
            objectName: "settingsSidebarDivider"
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.topMargin: Kirigami.Units.cornerRadius * 2
            Layout.bottomMargin: Kirigami.Units.cornerRadius * 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.12)
            Accessible.ignored: true
        }
        ColumnLayout {
            objectName: "settingsMainContent"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                currentIndex: root.currentPage
                DockItemsSettings {
                    id: itemsPage
                    settings: root.settings
                    applicationCatalog: root.applicationCatalog
                    applicationController: pinService
                }
                ScrollView {
                    id: generalScroll
                    objectName: "settingsGeneralScroll"
                    Layout.minimumHeight: 0
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Flickable {
                        id: generalViewport
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: generalPage.implicitHeight
                        DockGeneralSettings {
                            id: generalPage
                            settings: root.settings
                            autostart: root.autostart
                            recentApplications: root.recentApplications
                            width: generalViewport.width
                        }
                    }
                }
                ScrollView {
                    id: aboutScroll
                    objectName: "settingsAboutScroll"
                    Layout.minimumHeight: 0
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Flickable {
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: aboutPage.implicitHeight
                        id: aboutViewport
                        SettingsAbout {
                            id: aboutPage
                            objectName: "settingsAboutPage"
                            width: parent.width
                            licenseText: root.license ? root.license.text : ""
                            onLicenseReadRequested: licenseDialog.open()
                        }
                    }
                }
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
    LicenseDialog {
        id: licenseDialog
        licenseText: root.license ? root.license.text : ""
        onVisibleChanged: root.aboutDialogOpen = licenseDialog.visible
        onClosed: if (root.currentPage === 2) aboutPage.focusLicenseButton()
    }
}
