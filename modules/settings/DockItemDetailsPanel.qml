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
    signal chooseFolderRequested()
    signal layoutSelected(string layout)

    readonly property bool hasSelection: itemId.length > 0
    readonly property bool trashSelected: itemId === "item:trash"
    readonly property string itemTypeText: containerSelected ? qsTr("Folder")
        : trashSelected ? qsTr("Trash") : qsTr("Application")
    readonly property string pathText: containerPath.length > 0 ? containerPath : qsTr("Downloads")

    function focusContainerControl(): void {
        if (containerSelected) folderViewSetting.forceActiveFocus(Qt.TabFocusReason)
    }

    padding: Kirigami.Units.largeSpacing
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Item details")
    background: Rectangle {
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.smallSpacing
        border.width: 1
        border.color: Kirigami.Theme.disabledTextColor
    }

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
                model: [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
                currentIndex: ["grid", "list", "detail"].indexOf(root.containerLayout)
                Accessible.name: qsTr("Folder view")
                onActivated: root.layoutSelected(["grid", "list", "detail"][currentIndex])
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
