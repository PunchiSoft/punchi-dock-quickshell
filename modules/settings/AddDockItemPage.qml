// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config/LauncherIds.js" as LauncherIds

// Item editor of the dock settings. It owns the draft state and the rules that decide
// whether the item can be added; the header, the three field sets and the icon chooser
// are their own files.
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
    // button reveals all of them, and the icon button opens the theme chooser.
    property alias browsing: applicationFields.browsing
    property alias resultsDismissed: applicationFields.resultsDismissed
    property alias iconPanelOpen: iconChooser.opened
    // The chooser owns the theme adapter and the draft choice; the page exposes them
    // so a caller can read the icons and drive the selection without opening a window.
    readonly property alias iconModel: iconChooser.iconModel
    property alias pickedIconName: iconChooser.pickedIconName
    // Both item types pick their icon from the same theme chooser.
    readonly property bool iconPickerAvailable: itemType === "application"
        || itemType === "container"

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
        applicationFields.reset()
        root.iconPanelOpen = false
        if (itemType === "application") applicationFields.focusSearch(Qt.OtherFocusReason)
        else if (itemType === "container") containerFields.focusName(Qt.OtherFocusReason)
        else itemTypeSelector.forceActiveFocus(Qt.OtherFocusReason)
    }
    onItemTypeChanged: {
        // A chooser opened for the previous type must not survive the switch.
        root.iconPanelOpen = false
        if (visible) {
            if (itemType === "application") applicationFields.focusSearch(Qt.TabFocusReason)
            else if (itemType === "container") containerFields.focusName(Qt.TabFocusReason)
        }
    }
    function chooseApplication(appId: string): void {
        applicationFields.chooseApplication(appId)
    }
    function chooseIcon(iconName: string): void {
        root.iconPanelOpen = false
        if (root.itemType === "container") {
            root.containerIcon = iconName
            containerFields.focusIconButton()
            return
        }
        root.iconRequested(iconName)
        applicationFields.focusIconButton()
    }
    function openIconChooser(): void {
        if (!root.iconPickerAvailable) return
        if (root.iconPanelOpen) {
            iconChooser.close()
            return
        }
        iconChooser.open(root.itemType === "container" ? root.containerIcon
            : root.controller.selectedIconName)
    }
    function applyContainerPath(path: string): void {
        root.containerPath = path
        if (root.containerTitle === "" || root.containerTitle === qsTr("Folder")) {
            const parts = String(path).replace(/\/+$/, "").split("/")
            const name = parts.length > 0 ? parts[parts.length - 1] : ""
            if (name.length > 0) root.containerTitle = name
        }
    }

    // The page keeps its actions at the top, so the form below never pushes them out
    // of reach.
    AddDockItemHeader {
        canAdd: root.canAddItem
        onCancelRequested: root.cancelRequested()
        onAddRequested: root.addRequested()
        onDiscardRequested: root.discardRequested()
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

            ApplicationItemFields {
                id: applicationFields
                visible: root.itemType === "application"
                controller: root.controller
                labelWidth: root.labelWidth
                onSearchRequested: function(text) { root.searchRequested(text) }
                onSelectionRequested: function(appId) { root.selectionRequested(appId) }
                onIconChooserRequested: root.openIconChooser()
            }

            ContainerItemFields {
                id: containerFields
                visible: root.itemType === "container"
                labelWidth: root.labelWidth
                fanSupported: root.settings.fanSupported
                title: root.containerTitle
                iconName: root.containerIcon
                layoutMode: root.containerLayout
                path: root.containerPath
                hiddenEntries: root.containerHiddenEntries
                onTitleEdited: function(title) { root.containerTitle = title }
                onIconNameEdited: function(name) { root.containerIcon = name }
                onLayoutEdited: function(mode) { root.containerLayout = mode }
                onPathChosen: function(path) { root.applyContainerPath(path) }
                onEntriesChosen: function(names) { root.containerHiddenEntries = names }
                onIconChooserRequested: root.openIconChooser()
            }

            TrashItemFields {
                visible: root.itemType === "trash"
                labelWidth: root.labelWidth
                alreadyPinned: root.trashAlreadyPinned
            }
        }
    }

    IconChooser {
        id: iconChooser
        onAccepted: function(iconName) { root.chooseIcon(iconName) }
        onCancelled: {
            if (root.itemType === "container") containerFields.focusIconButton()
            else applicationFields.focusIconButton()
        }
    }

    // Spacer to keep form at the top and action buttons at the bottom
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
