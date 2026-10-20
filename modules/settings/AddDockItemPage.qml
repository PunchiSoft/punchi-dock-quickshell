// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../adapters/kde"
import "../../config/LauncherIds.js" as LauncherIds

ColumnLayout {
    id: root
    required property var controller
    required property var settings
    signal searchRequested(string text)
    signal selectionRequested(string appId)
    signal iconRequested(string iconName)
    signal addRequested()
    signal discardRequested()
    signal cancelRequested()
    property string itemType: "application"
    property string containerPath: ""
    property string containerTitle: qsTr("Folder")
    property string containerIcon: "folder"
    property string containerLayout: "grid"
    // Entries the new container's popup must skip; empty shows everything.
    property var containerHiddenEntries: []
    // Results and icons are opt-in: typing filters the applications, the search
    // button reveals all of them, and the icon button opens the theme grid.
    property bool browsing: false
    property bool resultsDismissed: false
    property bool iconPanelOpen: false
    // Both item types pick their icon from the same theme chooser.
    readonly property bool iconPickerAvailable: itemType === "application"
        || itemType === "container"
    // Icon highlighted in the chooser; applied only when the user accepts.
    property string pickedIconName: ""
    // Category shown in the chooser; Applications first, as the native dialog.
    property string iconContextFilter: ""
    // The default category applies until the user picks another one.
    property bool iconContextChosen: false
    onIconPanelOpenChanged: {
        if (!iconPanelOpen) return
        pickedIconName = root.itemType === "container" ? root.containerIcon
            : root.controller.selectedIconName
        root.iconContextChosen = false
        root.useDefaultIconContext()
    }
    function useDefaultIconContext(): void {
        if (root.iconContextChosen) return
        const contexts = root.iconModel.contexts || []
        root.iconContextFilter = contexts.indexOf("Applications") >= 0 ? "Applications" : ""
        root.iconModel.context = root.iconContextFilter
    }
    // Categories arrive after the background scan finishes.
    readonly property Connections iconContextChanges: Connections {
        target: root.iconModel
        function onContextsChanged() { root.useDefaultIconContext() }
    }
    readonly property var iconContextValues: [""].concat(root.iconModel.contexts || [])
    readonly property var iconContextLabels: {
        const values = root.iconContextValues
        const labels = []
        for (let index = 0; index < values.length; ++index)
            labels.push(root.iconContextLabel(values[index]))
        return labels
    }
    function iconContextLabel(context: string): string {
        switch (context) {
        case "": return qsTr("All")
        case "Actions": return qsTr("Actions")
        case "Animations": return qsTr("Animations")
        case "Applications": return qsTr("Applications")
        case "Categories": return qsTr("Categories")
        case "Devices": return qsTr("Devices")
        case "Emblems": return qsTr("Emblems")
        case "Emotes": return qsTr("Emotes")
        case "Filesystems": return qsTr("File systems")
        case "International": return qsTr("Languages")
        case "MimeTypes": return qsTr("File types")
        case "Places": return qsTr("Places")
        case "Status": return qsTr("Status")
        default: return context
        }
    }
    readonly property bool applicationListVisible: !root.resultsDismissed
        && (root.browsing || root.controller.query.length > 0)
    // Icons installed in the active Plasma theme, filtered by the picker search.
    readonly property var iconModel: IconThemeAdapter {}

    readonly property real labelWidth: Kirigami.Units.gridUnit * 5

    readonly property bool fanAvailable: settings.fanSupported
    readonly property var containerLayoutLabels: root.fanAvailable
        ? [qsTr("Grid"), qsTr("List"), qsTr("Detail"), qsTr("Fan")]
        : [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
    readonly property var containerLayoutModes: root.fanAvailable
        ? ["grid", "list", "detail", "fan"] : ["grid", "list", "detail"]
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
        root.browsing = false
        root.resultsDismissed = false
        root.iconPanelOpen = false
        if (itemType === "application") search.forceActiveFocus(Qt.OtherFocusReason)
        else if (itemType === "container") containerNameField.forceActiveFocus(Qt.OtherFocusReason)
        else itemTypeSelector.forceActiveFocus(Qt.OtherFocusReason)
    }
    onItemTypeChanged: {
        // A chooser opened for the previous type must not survive the switch.
        root.iconPanelOpen = false
        if (visible) {
            if (itemType === "application") search.forceActiveFocus(Qt.TabFocusReason)
            else if (itemType === "container") containerNameField.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    function chooseApplication(appId: string): void {
        root.selectionRequested(appId)
        root.resultsDismissed = true
        search.forceActiveFocus(Qt.TabFocusReason)
    }
    function chooseIcon(iconName: string): void {
        root.iconPanelOpen = false
        if (root.itemType === "container") {
            root.containerIcon = iconName
            containerIconButton.forceActiveFocus(Qt.TabFocusReason)
            return
        }
        root.iconRequested(iconName)
        iconButton.forceActiveFocus(Qt.TabFocusReason)
    }
    // The chooser writes the draft icon; mirror it into the name field, whose
    // text stops following the property once the user edits it.
    onContainerIconChanged: {
        if (containerIconField && containerIconField.text !== containerIcon)
            containerIconField.text = containerIcon
    }

    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }

    // Header: the page keeps its actions at the top, so the form below never
    // pushes them out of reach.
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.mediumSpacing
        Kirigami.Heading {
            text: qsTr("Add item to Dock")
            level: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
            // The title yields space so the header actions never leave the page.
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
        }
        Button {
            id: cancelButton
            objectName: "cancelAddItem"
            text: qsTr("Back")
            icon.name: "go-previous"
            onClicked: root.cancelRequested()
        }
        Button {
            id: confirmButton
            objectName: "confirmAddItem"
            text: qsTr("Add")
            icon.name: "list-add"
            enabled: root.canAddItem
            onClicked: root.addRequested()
        }
        Button {
            objectName: "discardAddItem"
            text: qsTr("Discard")
            icon.name: "edit-delete"
            onClicked: root.discardRequested()
        }
    }

    // The item editor uses the same grouped card surface as General, so the
    // form reads as one themed block instead of loose rows on the page.
    SettingsCard {
        objectName: "addItemFormCard"
        Layout.fillWidth: true
        title: qsTr("Item")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

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

            // Application fields. The results panel is created only when the user types
            // or asks for the whole list, so the form opens without it.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.itemType === "application"
                Label {
                    objectName: "applicationNameFieldLabel"
                    text: qsTr("Name:")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.preferredWidth: root.labelWidth
                    opacity: 0.8
                }
                TextField {
                    id: search
                    objectName: "applicationSearch"
                    Layout.fillWidth: true
                    placeholderText: qsTr("Type the application name or alias")
                    Accessible.name: qsTr("Search applications")
                    text: root.controller.query
                    onTextEdited: {
                        root.browsing = false
                        root.resultsDismissed = false
                        root.searchRequested(text)
                    }
                    // Editing writes the field text imperatively, which breaks the
                    // declarative binding above. Mirror the service query so opening
                    // or discarding the page always shows the real search state.
                    Connections {
                        target: root.controller
                        function onQueryChanged() { search.text = root.controller.query }
                    }
                }
                ToolButton {
                    id: browseButton
                    objectName: "browseApplications"
                    icon.name: "system-search"
                    display: AbstractButton.IconOnly
                    checkable: true
                    checked: root.browsing
                    Accessible.name: qsTr("Show all applications")
                    ToolTip.text: Accessible.name
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        root.resultsDismissed = false
                        root.browsing = checked
                    }
                }
            }

            Item {
                id: resultsHost
                Layout.fillWidth: true
                // The list hangs over the form from the typing row, so opening it
                // never pushes the remaining fields past the card.
                Layout.preferredHeight: 0
                Loader {
                    id: resultsArea
                    objectName: "applicationResultsArea"
                    // It starts at the search field and reaches the magnifier's edge.
                    x: root.labelWidth + Kirigami.Units.largeSpacing
                    width: parent.width - x
                    height: Kirigami.Units.gridUnit * 14
                    z: 1
                    visible: root.itemType === "application" && root.applicationListVisible
                    active: root.itemType === "application" && root.applicationListVisible
                    sourceComponent: resultsPanel
                }
            }

            Component {
                id: resultsPanel
                Rectangle {
                    objectName: "applicationResultsPanel"
                    color: Kirigami.Theme.backgroundColor
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, 0.25)
                    radius: Kirigami.Units.cornerRadius
                    ScrollView {
                        objectName: "applicationResultsScroll"
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ListView {
                            id: applications
                            objectName: "applicationSearchResults"
                            model: root.controller.applications
                            cacheBuffer: 0
                            activeFocusOnTab: true
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
                                onClicked: root.chooseApplication(appId)
                                Keys.onReturnPressed: root.chooseApplication(appId)
                            }
                        }
                    }
                    Label {
                        objectName: "applicationResultsEmpty"
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        visible: root.controller.applications.count === 0
                        text: qsTr("No applications found.")
                    }
                }
            }

            // Icon chosen for the item. The application icon stays the fallback.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.itemType === "application"
                Label {
                    objectName: "applicationIconLabel"
                    text: qsTr("Icon:")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.preferredWidth: root.labelWidth
                    opacity: 0.8
                }
                Button {
                    id: iconButton
                    objectName: "applicationIconButton"
                    // The icon can be chosen before the application, so the button stays
                    // available while the type is Application.
                    display: AbstractButton.IconOnly
                    icon.name: root.controller.selectedIconName.length > 0
                        ? root.controller.selectedIconName : "application-x-executable"
                    text: qsTr("Choose icon")
                    Accessible.name: text
                    ToolTip.text: text
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        root.iconModel.ensureLoaded()
                        root.iconPanelOpen = !root.iconPanelOpen
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Icon chooser, modeled on the KDE Menu Editor dialog: a separate window
            // with its own search field and icon grid.
            Loader {
                id: iconArea
                objectName: "iconPickerArea"
                active: root.iconPickerAvailable && root.iconPanelOpen
                sourceComponent: iconDialogComponent
            }

            Component {
                id: iconDialogComponent
                Window {
                    id: iconDialog
                    objectName: "iconPickerPopup"
                    title: qsTr("Select Icon")
                    transientParent: root.Window.window
                    flags: Qt.Dialog
                    modality: Qt.WindowModal
                    width: Kirigami.Units.gridUnit * 30
                    height: Kirigami.Units.gridUnit * 24
                    visible: true
                    color: Kirigami.Theme.backgroundColor
                    // Closing the dialog is the only exit; the loader then drops it.
                    onClosing: root.iconPanelOpen = false
                    onVisibleChanged: {
                        if (!visible) return
                        requestActivate()
                        iconSearch.forceActiveFocus(Qt.TabFocusReason)
                    }
                    // The dialog is its own window, so it sets the color set explicitly
                    // instead of inheriting the settings window.
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.Theme.backgroundColor
                        Kirigami.Theme.inherit: false
                        Kirigami.Theme.colorSet: Kirigami.Theme.Window
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            spacing: Kirigami.Units.mediumSpacing
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.mediumSpacing
                                ComboBox {
                                    id: iconContext
                                    objectName: "iconContext"
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                                    model: root.iconContextLabels
                                    Accessible.name: qsTr("Icon category")
                                    // The shown label follows the active filter; the
                                    // control's own index is not a reliable mirror.
                                    displayText: root.iconContextLabel(root.iconContextFilter)
                                    onActivated: {
                                        root.iconContextChosen = true
                                        root.iconContextFilter = root.iconContextValues[currentIndex]
                                        root.iconModel.context = root.iconContextFilter
                                    }
                                }
                                TextField {
                                    id: iconSearch
                                    objectName: "iconSearch"
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Search icons…")
                                    Accessible.name: qsTr("Search icons")
                                    onTextEdited: root.iconModel.query = text
                                    Keys.onEscapePressed: root.iconPanelOpen = false
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                ScrollView {
                                    anchors.fill: parent
                                    clip: true
                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                    GridView {
                                        id: iconGrid
                                        objectName: "iconGrid"
                                        // The native chooser draws 60px tiles with a caption.
                                        cellWidth: 92
                                        cellHeight: 92
                                        model: root.iconModel
                                        cacheBuffer: 0
                                        boundsBehavior: Flickable.StopAtBounds
                                        Keys.onEscapePressed: root.iconPanelOpen = false
                                        delegate: ItemDelegate {
                                            id: iconTile
                                            required property string iconName
                                            objectName: "iconResult-" + iconName
                                            width: iconGrid.cellWidth
                                            height: iconGrid.cellHeight
                                            highlighted: root.pickedIconName === iconName
                                            onClicked: root.pickedIconName = iconName
                                            // The native chooser captions every tile.
                                            contentItem: ColumnLayout {
                                                spacing: Kirigami.Units.smallSpacing
                                                Kirigami.Icon {
                                                    id: tileIcon
                                                    Native.IconThemeRefresh.enabled: true
                                                    source: iconTile.iconName
                                                    // A theme can list an asset Qt cannot
                                                    // resolve; show the standard glyph
                                                    // instead of an empty tile.
                                                    fallback: "image-missing"
                                                    Layout.alignment: Qt.AlignHCenter
                                                    // The native chooser renders tiles at 48px.
                                                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                                }
                                                Label {
                                                    text: iconTile.iconName
                                                    textFormat: Text.PlainText
                                                    color: Kirigami.Theme.textColor
                                                    font: Kirigami.Theme.smallFont
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                    // A name the theme cannot paint stays
                                                    // offered but reads as unavailable.
                                                    opacity: tileIcon.valid ? 1.0 : 0.6
                                                    Layout.fillWidth: true
                                                }
                                        }
                                    }
                                }
                            }
                            Label {
                                objectName: "iconPickerEmpty"
                                anchors.centerIn: parent
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                opacity: 0.7
                                visible: root.iconModel.count === 0
                                text: qsTr("No icons found.")
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Button {
                                objectName: "applyIconChoice"
                                text: qsTr("OK")
                                icon.name: "dialog-ok-apply"
                                enabled: root.pickedIconName.length > 0
                                onClicked: root.chooseIcon(root.pickedIconName)
                            }
                            Button {
                                objectName: "cancelIconChoice"
                                text: qsTr("Cancel")
                                icon.name: "dialog-cancel"
                                onClicked: root.iconPanelOpen = false
                            }
                        }
                    }
                    }
                }
            }

            // Selected application description, below the icon.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: root.itemType === "application"
                Label {
                    objectName: "applicationDescriptionLabel"
                    text: qsTr("Description:")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
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
                        Accessible.name: qsTr("Choose icon")
                        ToolTip.text: Accessible.name
                        ToolTip.visible: hovered || activeFocus
                        ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: {
                            root.iconModel.ensureLoaded()
                            root.iconPanelOpen = !root.iconPanelOpen
                        }
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
                    model: root.containerLayoutLabels
                    currentIndex: root.containerLayoutModes.indexOf(root.containerLayout)
                    Accessible.name: qsTr("Container view")
                    onActivated: root.containerLayout = root.containerLayoutModes[currentIndex]
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

                // What the popup lists: the folder contents arrive here so the owner
                // can keep entries out before adding the container.
                FolderEntrySelection {
                    objectName: "containerEntrySelection"
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    // The list lines up with the controls and only grows once a folder
                    // is chosen; until then the form shows a single hint line.
                    Layout.leftMargin: root.labelWidth + Kirigami.Units.largeSpacing
                    Layout.preferredHeight: root.containerPath.length > 0
                        ? Kirigami.Units.gridUnit * 10 : -1
                    folderPath: root.containerPath
                    // The editor lists nothing until a folder is chosen.
                    folderChosen: root.containerPath.length > 0
                    hiddenEntries: root.containerHiddenEntries
                    onEntriesChosen: function(names) { root.containerHiddenEntries = names }
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

}
