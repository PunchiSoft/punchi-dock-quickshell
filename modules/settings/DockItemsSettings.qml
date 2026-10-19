// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../services"
import "../../config"

ColumnLayout {
    id: root
    required property ShellSettings settings
    property var applicationCatalog: null
    property var applicationController: null
    property int orderRevision: 0
    property bool addingItem: false
    readonly property bool canRemoveSelected: editor.canRemove
    function focusFirst(): void { addButton.forceActiveFocus(Qt.OtherFocusReason) }
    spacing: Kirigami.Units.largeSpacing
    PinnedItemsEditService { id: editor; settings: root.settings }
    // Folder containers: the selected item may point at a folder on disk. An
    // empty path is the built-in Downloads folder.
    readonly property var selectedContainer: root.settings.container(editor.selectedAppId)
    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }
    function folderName(path: string): string {
        const parts = String(path).replace(/\/+$/, "").split("/")
        const name = parts.length > 0 ? parts[parts.length - 1] : ""
        return name.length > 0 ? name : qsTr("Folder")
    }
    function beginAddItem(): void {
        if (!applicationController) return
        applicationController.begin()
        addPage.itemType = "application"
        addPage.containerPath = ""
        addPage.containerTitle = qsTr("Folder")
        addPage.containerIcon = "folder"
        addPage.containerLayout = "grid"
        addingItem = true
        Qt.callLater(addPage.focusFirst)
    }
    function cancelAddItem(restoreFocus: bool): void {
        if (applicationController) applicationController.cancel()
        addPage.itemType = "application"
        addPage.containerPath = ""
        addPage.containerTitle = qsTr("Folder")
        addPage.containerIcon = "folder"
        addPage.containerLayout = "grid"
        addingItem = false
        if (restoreFocus) Qt.callLater(addButton.forceActiveFocus)
    }
    function acceptAddItem(): void {
        let accepted = false
        if (addPage.itemType === "application") accepted = applicationController.accept()
        else if (addPage.itemType === "container") accepted = pinContainer(addPage.containerPath, addPage.containerTitle, addPage.containerIcon, addPage.containerLayout)
        else if (addPage.itemType === "trash") accepted = pinTrash()
        if (!accepted) return
        if (addPage.itemType !== "application") applicationController.cancel()
        addingItem = false
        addPage.containerPath = ""
        addPage.containerTitle = qsTr("Folder")
        addPage.containerIcon = "folder"
        Qt.callLater(focusFirst)
    }
    function pinContainer(path: string, title: var, icon: var, layout: var): bool {
        if (root.settings.pinnedIds.length >= 32) return false
        let containerTitle = root.folderName(path)
        let containerIcon = "folder"
        let containerLayout = "grid"
        if (arguments.length === 2) {
            containerLayout = arguments[1] || "grid"
        } else if (arguments.length >= 4) {
            if (title && String(title).trim().length > 0) containerTitle = String(title).trim()
            if (icon && String(icon).trim().length > 0) containerIcon = String(icon).trim()
            containerLayout = layout || "grid"
        }
        const id = root.settings.addContainer(path, containerTitle, containerIcon, containerLayout)
        if (id.length === 0) return false
        const pins = root.settings.pinnedIds.slice()
        if (pins.indexOf(id) >= 0) return false
        // Trash stays last, matching the default profile order.
        const trash = pins.indexOf("item:trash")
        if (trash >= 0) pins.splice(trash, 0, id)
        else pins.push(id)
        root.settings.pinnedIds = pins
        editor.select(id)
        return true
    }
    function pinTrash(): bool {
        const pins = root.settings.pinnedIds.slice()
        if (pins.indexOf("item:trash") >= 0 || pins.length >= 32) return false
        pins.push("item:trash")
        root.settings.pinnedIds = pins
        editor.select("item:trash")
        return true
    }
    RowLayout {
        objectName: "dockItemToolbar"
        Layout.fillWidth: true
        Button {
            id: addButton
            objectName: "addDockItem"
            text: qsTr("Add Item")
            icon.name: "list-add"
            enabled: !root.addingItem
            onClicked: root.beginAddItem()
        }
        ToolButton {
            objectName: "configureDockItem"
            text: qsTr("Configure item")
            icon.name: "configure"
            display: AbstractButton.IconOnly
            enabled: !root.addingItem && root.selectedContainer !== null
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: folderViewSetting.forceActiveFocus(Qt.TabFocusReason)
        }
        ToolButton {
            objectName: "moveDockItemUp"
            text: qsTr("Move up")
            icon.name: "go-up"
            display: AbstractButton.IconOnly
            enabled: !root.addingItem && editor.canMoveUp && items.currentIndex >= 0
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: editor.move(-1)
        }
        ToolButton {
            objectName: "moveDockItemDown"
            text: qsTr("Move down")
            icon.name: "go-down"
            display: AbstractButton.IconOnly
            enabled: !root.addingItem && editor.canMoveDown && items.currentIndex >= 0
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: editor.move(1)
        }
        ToolButton {
            objectName: "removeDockItem"
            text: qsTr("Remove from Dock")
            icon.name: "edit-delete"
            display: AbstractButton.IconOnly
            enabled: !root.addingItem && editor.canRemove
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: editor.removeSelected()
        }
        Item { Layout.fillWidth: true }
    }
    PinnedApplications { id: entries; catalog: root.applicationCatalog; pinnedIds: root.settings.pinnedIds }
    Connections {
        target: entries
        function onRowsMoved() { root.orderRevision++ }
        function onRowsInserted() { root.orderRevision++ }
        function onRowsRemoved() { root.orderRevision++ }
        function onModelReset() { root.orderRevision++ }
    }
    StackLayout {
        id: itemsContent
        objectName: "itemsContent"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        currentIndex: root.addingItem ? 1 : 0
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: Kirigami.Units.gridUnit * 10
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ListView {
                    id: items
                    objectName: "settingsDockItems"
                    model: entries
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Dock items")
                    currentIndex: {
                        root.orderRevision
                        root.settings.pinnedIds
                        for (let row = 0; row < entries.count; ++row)
                            if (entries.get(row).appId === editor.selectedAppId) return row
                        return -1
                    }
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                    // A model move can briefly leave the view's cursor at its old row.
                    // Keyboard intent follows the editor's selected application identity.
                    Keys.onUpPressed: if (count > 0) editor.select(entries.get(Math.max(0, editor.selectedIndex - 1)).appId)
                    Keys.onDownPressed: if (count > 0) editor.select(entries.get(Math.min(count - 1, editor.selectedIndex + 1)).appId)
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ApplicationListRow {
                        required property int index
                        required property string appId
                        required property string title
                        required iconName
                        objectName: "configuredItem-" + appId
                        width: ListView.view.width
                        text: title
                        highlighted: editor.selectedAppId === appId
                        onClicked: editor.select(appId)
                        Keys.onReturnPressed: editor.select(appId)
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedContainer !== null
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        objectName: "containerFolderPath"
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        text: root.selectedContainer && String(root.selectedContainer.path).length > 0
                            ? String(root.selectedContainer.path) : qsTr("Downloads")
                    }
                    Button {
                        objectName: "containerChooseFolder"
                        text: qsTr("Choose folder…")
                        icon.name: "folder-open"
                        onClicked: folderDialog.open()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("View"); Layout.fillWidth: true }
                    ComboBox {
                        id: folderViewSetting
                        objectName: "folderViewSetting"
                        model: [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
                        currentIndex: ["grid", "list", "detail"].indexOf(root.selectedContainer
                            ? root.selectedContainer.layout : "grid")
                        Accessible.name: qsTr("Folder view")
                        onActivated: root.settings.setContainerLayout(editor.selectedAppId,
                            ["grid", "list", "detail"][currentIndex])
                    }
                }
            }
            FolderDialog {
                id: folderDialog
                title: qsTr("Choose folder")
                onAccepted: {
                    const path = root.localPath(selectedFolder)
                    root.settings.setContainerPath(editor.selectedAppId, path)
                }
            }
        }
        AddDockItemPage {
            id: addPage
            controller: root.applicationController
            settings: root.settings
            onSearchRequested: function(text) { root.applicationController.search(text) }
            onSelectionRequested: function(appId) { root.applicationController.select(appId) }
            onAddRequested: root.acceptAddItem()
            onCancelRequested: root.cancelAddItem(true)
        }
    }
}
