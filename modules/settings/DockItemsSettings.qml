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
    property int orderRevision: 0
    signal addRequested()
    function focusFirst(): void { addButton.forceActiveFocus(Qt.OtherFocusReason) }
    spacing: Kirigami.Units.largeSpacing
    PinnedItemsEditService { id: editor; settings: root.settings }
    // Folder containers: the selected item may point at a folder on disk. An
    // empty path is the built-in Downloads folder.
    readonly property var selectedContainer: root.settings.container(editor.selectedAppId)
    property bool addingContainer: false
    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }
    function folderName(path: string): string {
        const parts = String(path).replace(/\/+$/, "").split("/")
        const name = parts.length > 0 ? parts[parts.length - 1] : ""
        return name.length > 0 ? name : qsTr("Folder")
    }
    function pinContainer(path: string): void {
        const id = root.settings.addContainer(path, root.folderName(path), "folder")
        if (id.length === 0) return
        const pins = root.settings.pinnedIds.slice()
        if (pins.indexOf(id) >= 0) return
        // Trash stays last, matching the default profile order.
        const trash = pins.indexOf("item:trash")
        if (trash >= 0) pins.splice(trash, 0, id)
        else pins.push(id)
        root.settings.pinnedIds = pins
        editor.select(id)
    }
    RowLayout {
        Layout.fillWidth: true
        Button {
            id: addButton
            objectName: "addDockApplication"
            text: qsTr("Add Item")
            icon.name: "list-add"
            enabled: root.applicationCatalog !== null
            onClicked: root.addRequested()
        }
        Button {
            objectName: "addDockContainer"
            text: qsTr("Add folder")
            icon.name: "folder-new"
            onClicked: { root.addingContainer = true; folderDialog.open() }
        }
        ToolButton {
            objectName: "moveDockItemUp"
            text: qsTr("Move up")
            icon.name: "go-up"
            display: AbstractButton.IconOnly
            enabled: editor.canMoveUp && items.currentIndex >= 0
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
            enabled: editor.canMoveDown && items.currentIndex >= 0
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: editor.move(1)
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
                onClicked: { root.addingContainer = false; folderDialog.open() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("View"); Layout.fillWidth: true }
            ComboBox {
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
            if (root.addingContainer) root.pinContainer(path)
            else root.settings.setContainerPath(editor.selectedAppId, path)
            root.addingContainer = false
        }
    }
}
