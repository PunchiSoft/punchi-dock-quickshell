// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../config/LauncherIds.js" as LauncherIds

ColumnLayout {
    id: root
    required property var controller
    required property var settings
    signal searchRequested(string text)
    signal selectionRequested(string appId)
    signal addRequested()
    signal cancelRequested()
    property string itemType: "application"
    property string containerPath: ""
    property string containerTitle: qsTr("Folder")
    property string containerIcon: "folder"
    property string containerLayout: "grid"

    readonly property real labelWidth: Kirigami.Units.gridUnit * 5

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
    objectName: "addDockItemPage"
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Kirigami.Units.mediumSpacing

    function focusFirst(): void {
        if (itemType === "application") search.forceActiveFocus(Qt.OtherFocusReason)
        else if (itemType === "container") containerNameField.forceActiveFocus(Qt.OtherFocusReason)
        else itemTypeSelector.forceActiveFocus(Qt.OtherFocusReason)
    }
    onItemTypeChanged: {
        if (visible) {
            if (itemType === "application") search.forceActiveFocus(Qt.TabFocusReason)
            else if (itemType === "container") containerNameField.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }

    // Header row with title and close 'X' button matching Punchi Dock
    RowLayout {
        Layout.fillWidth: true
        Kirigami.Heading {
            text: qsTr("Add item to Dock")
            level: 2
            Layout.fillWidth: true
        }
        ToolButton {
            objectName: "closeAddDockItem"
            icon.name: "window-close"
            display: AbstractButton.IconOnly
            Accessible.name: qsTr("Close")
            ToolTip.text: text
            ToolTip.visible: hovered
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: root.cancelRequested()
        }
    }

    // Type selector row
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Label {
            text: qsTr("Type:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        ComboBox {
            id: itemTypeSelector
            objectName: "addItemType"
            Layout.fillWidth: true
            model: [qsTr("Application"), qsTr("Popup Container"), qsTr("Trash")]
            currentIndex: ["application", "container", "trash"].indexOf(root.itemType)
            Accessible.name: qsTr("Item type")
            onActivated: root.itemType = ["application", "container", "trash"][currentIndex]
        }
    }

    // Application search
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

    // Application search results
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
                selectionActive: root.controller.selectedAppId.length > 0
                highlighted: root.controller.selectedAppId === appId
                onClicked: root.selectionRequested(appId)
                Keys.onReturnPressed: root.selectionRequested(appId)
            }
        }
    }

    // Application details
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
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
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
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
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
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        Label {
            objectName: "applicationDescriptionValue"
            text: root.controller.selectedApplication ? root.controller.selectedApplication.description : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // Container Item Editor (Form layout identical to Punchi Dock reference)
    GridLayout {
        id: containerItemEditor
        objectName: "containerItemEditor"
        visible: root.itemType === "container"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.mediumSpacing

        Label {
            text: qsTr("Name:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        TextField {
            id: containerNameField
            objectName: "newContainerName"
            Layout.fillWidth: true
            text: root.containerTitle
            placeholderText: qsTr("Folder")
            Accessible.name: qsTr("Container name")
            onTextEdited: root.containerTitle = text
        }

        Label {
            text: qsTr("Icon:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Button {
                id: containerIconButton
                objectName: "newContainerIconButton"
                icon.name: root.containerIcon.length > 0 ? root.containerIcon : "folder"
                display: AbstractButton.IconOnly
                Accessible.name: qsTr("Icon preview")
            }
            TextField {
                id: containerIconField
                objectName: "newContainerIcon"
                Layout.fillWidth: true
                text: root.containerIcon
                placeholderText: "folder"
                Accessible.name: qsTr("Icon name")
                onTextEdited: root.containerIcon = text
            }
        }

        Label {
            text: qsTr("View:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        ComboBox {
            id: newContainerLayout
            objectName: "newContainerLayout"
            Layout.fillWidth: true
            model: [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
            currentIndex: ["grid", "list", "detail"].indexOf(root.containerLayout)
            Accessible.name: qsTr("Container view")
            onActivated: root.containerLayout = ["grid", "list", "detail"][currentIndex]
        }

        Label {
            text: qsTr("Folder:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
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
    }

    // Trash Item Editor
    GridLayout {
        visible: root.itemType === "trash"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.mediumSpacing

        Label {
            text: qsTr("Name:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        Label {
            text: qsTr("Trash")
            font.bold: true
            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Icon:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        Kirigami.Icon {
            objectName: "newTrashPreview"
            source: "user-trash"
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Accessible.ignored: true
        }

        Item {
            visible: root.trashAlreadyPinned
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.smallSpacing
        }
        Label {
            visible: root.trashAlreadyPinned
            Layout.columnSpan: 2
            Layout.fillWidth: true
            color: Kirigami.Theme.neutralTextColor
            text: qsTr("Trash is already present in the dock.")
        }
    }

    // Spacer to keep form at the top and action buttons at the bottom
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose folder")
        onAccepted: {
            const path = root.localPath(selectedFolder)
            root.containerPath = path
            if (root.containerTitle === "" || root.containerTitle === qsTr("Folder")) {
                const parts = String(path).replace(/\/+$/, "").split("/")
                const name = parts.length > 0 ? parts[parts.length - 1] : ""
                if (name.length > 0) root.containerTitle = name
            }
        }
    }

    // Action buttons matching Image 1: [ Añadir ] [ Descartar ]
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        Item { Layout.fillWidth: true }
        Button {
            id: confirmButton
            objectName: "confirmAddItem"
            text: qsTr("Add")
            enabled: root.canAddItem
            onClicked: root.addRequested()
        }
        Button {
            id: cancelButton
            objectName: "cancelAddItem"
            text: qsTr("Discard")
            onClicked: root.cancelRequested()
        }
    }
}
