// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Pane {
    id: root
    objectName: "dockItemDetails"
    property string itemId: ""
    property string itemTitle: ""
    property string itemIconName: ""
    property bool containerSelected: false
    property string containerPath: ""
    property string containerLayout: "grid"
    // The arc unfolds from the row that faces the panel, so a vertical dock
    // offers the three flat presentations only.
    property bool fanAvailable: true
    // A folder container can be told whether selecting a directory enters it.
    // Applications and Trash have no subfolders, so the switch stays away.
    property bool browseSubfolders: true
    // Entries the container popup skips; empty shows everything.
    property var hiddenEntries: []
    readonly property var layoutLabels: root.fanAvailable
        ? [qsTr("Grid"), qsTr("List"), qsTr("Detail"), qsTr("Fan")]
        : [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
    readonly property var layoutModes: root.fanAvailable
        ? ["grid", "list", "detail", "fan"] : ["grid", "list", "detail"]
    signal chooseFolderRequested()
    signal layoutSelected(string layout)
    signal browseSubfoldersSelected(bool enabled)
    signal hiddenEntriesSelected(var names)

    readonly property bool hasSelection: itemId.length > 0
    readonly property bool trashSelected: itemId === "item:trash"
    readonly property bool homeContainer: containerSelected && itemId === "item:folder:home"
        && containerPath.length === 0
    readonly property string itemTypeText: containerSelected ? qsTr("Folder")
        : trashSelected ? qsTr("Trash") : qsTr("Application")
    readonly property string pathText: containerPath.length > 0 ? containerPath
        : homeContainer ? qsTr("Home") : qsTr("Downloads")

    function focusContainerControl(): void {
        if (containerSelected) folderViewSetting.forceActiveFocus(Qt.TabFocusReason)
    }

    padding: Kirigami.Units.largeSpacing
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Item details")
    background: SettingsCardFrame {}

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasSelection
            spacing: Kirigami.Units.mediumSpacing
            Kirigami.Icon {
                source: root.itemIconName || "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                Accessible.ignored: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    objectName: "itemDetailsTitle"
                    Layout.fillWidth: true
                    text: root.itemTitle
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }
                Label {
                    objectName: "itemDetailsType"
                    Layout.fillWidth: true
                    text: root.itemTypeText
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    opacity: 0.7
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.containerSelected
            spacing: Kirigami.Units.smallSpacing
            Label {
                Layout.fillWidth: true
                text: qsTr("Folder")
                opacity: 0.7
            }
            Label {
                objectName: "containerFolderPath"
                Layout.fillWidth: true
                text: root.pathText
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
            }
            Button {
                objectName: "containerChooseFolder"
                Layout.fillWidth: true
                text: qsTr("Choose folder…")
                icon.name: "folder-open"
                onClicked: root.chooseFolderRequested()
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.mediumSpacing
                text: qsTr("View")
                opacity: 0.7
            }
            ComboBox {
                id: folderViewSetting
                objectName: "folderViewSetting"
                Layout.fillWidth: true
                model: root.layoutLabels
                currentIndex: root.layoutModes.indexOf(root.containerLayout)
                Accessible.name: qsTr("Folder view")
                onActivated: root.layoutSelected(root.layoutModes[currentIndex])
            }
            Switch {
                id: browseSubfoldersSwitch
                objectName: "containerBrowseSubfolders"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: qsTr("Browse subfolders")
                Accessible.name: qsTr("Browse subfolders")
                checked: root.browseSubfolders
                onToggled: {
                    root.browseSubfoldersSelected(checked)
                    // The gesture breaks the declarative binding; the stored
                    // container stays the source of truth.
                    checked = Qt.binding(function() { return root.browseSubfolders })
                }
            }
            FolderEntrySelection {
                objectName: "detailsEntrySelection"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.mediumSpacing
                Layout.minimumHeight: Kirigami.Units.gridUnit * 8
                folderPath: root.containerPath
                homeFolder: root.homeContainer
                hiddenEntries: root.hiddenEntries
                onEntriesChosen: function(names) { root.hiddenEntriesSelected(names) }
            }
        }

        Label {
            objectName: "itemDetailsNote"
            Layout.fillWidth: true
            visible: !root.hasSelection
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            text: qsTr("<b>Note:</b> Choose what the dock shows and in what order. <b>Add Item</b> places an element; selecting it lets you configure, reorder, or remove it.")
        }

        Item { Layout.fillHeight: true }
    }
}
