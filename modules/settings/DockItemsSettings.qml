// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
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
}
