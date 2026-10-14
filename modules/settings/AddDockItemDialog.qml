// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../config/LauncherIds.js" as LauncherIds

Dialog {
    id: root
    required property var controller
    required property var settings
    property Item hostItem: null
    property real hostWidth: parent ? parent.width : 0
    property real hostHeight: parent ? parent.height : 0
    signal searchRequested(string text)
    signal selectionRequested(string appId)
    signal addRequested()
    property string itemType: "application"
    property string containerPath: ""
    property string containerLayout: "grid"
    readonly property bool trashAlreadyPinned: settings.pinnedIds.indexOf("item:trash") >= 0
    readonly property bool canAddContainer: containerPath.length > 0
        && LauncherIds.validContainerPath(containerPath)
        && settings.pinnedIds.length < LauncherIds.maximumPins
        && settings.containers.length < LauncherIds.maximumPins
    readonly property bool canAddTrash: !trashAlreadyPinned
        && settings.pinnedIds.length < LauncherIds.maximumPins
    readonly property bool canAddItem: itemType === "application" ? controller.canAdd
        : itemType === "container" ? canAddContainer
        : itemType === "trash" && canAddTrash
    title: qsTr("Add item to Dock")
    objectName: "addDockItemDialog"
    parent: hostItem && hostItem.Window.window ? hostItem.Window.window.contentItem : null
    popupType: Popup.Item
    modal: true
    focus: true
    width: Math.min(Kirigami.Units.gridUnit * 32, Math.max(0, hostWidth - Kirigami.Units.largeSpacing * 2))
    height: Math.min(implicitHeight, Math.max(0, hostHeight - Kirigami.Units.largeSpacing * 2))
    x: (hostWidth - width) / 2
    y: (hostHeight - height) / 2
    closePolicy: Popup.CloseOnEscape
    onOpened: itemTypeSelector.forceActiveFocus(Qt.PopupFocusReason)
    onItemTypeChanged: if (itemType === "application" && opened)
        search.forceActiveFocus(Qt.PopupFocusReason)
    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing
        ComboBox {
            id: itemTypeSelector
            objectName: "addItemType"
            Layout.fillWidth: true
            model: [qsTr("Application"), qsTr("Popup Container"), qsTr("Trash")]
            currentIndex: ["application", "container", "trash"].indexOf(root.itemType)
            Accessible.name: qsTr("Item type")
            onActivated: root.itemType = ["application", "container", "trash"][currentIndex]
        }
        TextField {
            id: search
            objectName: "applicationSearch"
            Layout.fillWidth: true
            placeholderText: qsTr("Name or alias")
            Accessible.name: qsTr("Search applications")
            text: root.controller.query
            visible: root.itemType === "application"
            onTextEdited: root.searchRequested(text)
        }
        ScrollView {
            objectName: "applicationResultsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3
            clip: true
            visible: root.itemType === "application"
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ListView {
                id: applications
                objectName: "applicationSearchResults"
                model: root.visible ? root.controller.applications : null
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: ApplicationListRow {
                    required property string appId
                    required property string name
                    required property string appIconName
                    iconName: appIconName
                    objectName: "applicationResult-" + appId
                    width: ListView.view.width
                    text: name
                    highlighted: root.controller.selectedAppId === appId
                    onClicked: root.selectionRequested(appId)
                    Keys.onReturnPressed: root.selectionRequested(appId)
                }
            }
        }
        GridLayout {
            objectName: "applicationDetails"
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: root.itemType === "application"
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.mediumSpacing
            Label {
                objectName: "applicationNameLabel"
                text: qsTr("Name:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Label {
                objectName: "applicationNameValue"
                text: root.controller.selectedApplication ? root.controller.selectedApplication.name : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                objectName: "applicationIconLabel"
                text: qsTr("Icon:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Kirigami.Icon {
                Native.IconThemeRefresh.enabled: true
                objectName: "applicationPreviewIcon"
                source: root.controller.selectedApplication ? root.controller.selectedApplication.appIconName : "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Accessible.ignored: true
            }
            Label {
                objectName: "applicationDescriptionLabel"
                text: qsTr("Description:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Label {
                objectName: "applicationDescriptionValue"
                text: root.controller.selectedApplication ? root.controller.selectedApplication.description : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        ColumnLayout {
            objectName: "containerItemEditor"
            visible: root.itemType === "container"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Label { text: qsTr("Folder"); font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    objectName: "newContainerPath"
                    Layout.fillWidth: true
                    text: root.containerPath.length > 0 ? root.containerPath : qsTr("No folder selected")
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                }
                Button {
                    objectName: "chooseNewContainerFolder"
                    text: qsTr("Choose folder…")
                    icon.name: "folder-open"
                    onClicked: folderDialog.open()
                }
            }
            Label { text: qsTr("View"); font.bold: true }
            ComboBox {
                id: newContainerLayout
                objectName: "newContainerLayout"
                Layout.fillWidth: true
                model: [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
                currentIndex: ["grid", "list", "detail"].indexOf(root.containerLayout)
                Accessible.name: qsTr("Container view")
                onActivated: root.containerLayout = ["grid", "list", "detail"][currentIndex]
            }
        }
        Kirigami.Icon {
            objectName: "newTrashPreview"
            visible: root.itemType === "trash"
            source: "user-trash"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Accessible.ignored: true
        }
        FolderDialog {
            id: folderDialog
            title: qsTr("Choose folder")
            onAccepted: root.containerPath = root.localPath(selectedFolder)
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Item { Layout.fillWidth: true }
            Button {
                objectName: "confirmAddItem"
                text: qsTr("Add")
                icon.name: "list-add"
                enabled: root.canAddItem
                onClicked: root.addRequested()
            }
            Button {
                objectName: "discardAddItem"
                text: qsTr("Discard")
                onClicked: root.reject()
            }
        }
    }
}
