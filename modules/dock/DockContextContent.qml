// SPDX-License-Identifier: GPL-3.0-or-later
// Shares the tooltip balloon silhouette with compact themed menu rows.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../components"
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root
    property string itemName: ""
    property var actions: []
    property var recentDocuments: null
    property var places: null
    property var media: null
    property var settings: null
    property var minimizeEffectController: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool canPin: false
    property bool pinned: false
    property bool trashItem: false
    property bool dockBackground: false
    property bool folderItem: false
    property var folderContainer: null
    property Item folderSortNameAction: null
    property bool canEmptyTrash: false
    property string openDockSubmenu: ""
    property string tailEdge: "bottom"
    readonly property bool verticalTail: tailEdge === "left" || tailEdge === "right"
    property real pointerY: height / 2
    property real pointerX: width / 2
    readonly property real pointerHeight: Kirigami.Units.largeSpacing
    readonly property real pointerCenter: surface.pointerCenter
    readonly property real contentPadding: Kirigami.Units.largeSpacing
    signal actionRequested(string actionId)
    signal mediaCommandRequested(string command)
    signal placeRequested(string resource)
    signal morePlacesRequested()
    signal placesGroupRequested(string group)
    signal placesBackRequested()
    signal recentRequested(string resource)
    signal forgetRecentRequested()
    signal newWindowRequested()
    signal unpinRequested()
    signal pinRequested()
    signal settingsRequested()
    signal closeRequested()
    signal openTrashRequested()
    signal openFolderRequested()
    signal folderSortRequested(string sortMode)
    signal folderLayoutRequested(string layout)
    signal emptyTrashRequested()
    signal autoHideRequested()
    signal magnificationRequested()
    signal dockEdgeRequested(string edge)
    signal minimizeEffectRequested(string effect)
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    readonly property real labelWidth: trashItem
        ? Math.max(labelMetrics.advanceWidth(openTrashAction.text), labelMetrics.advanceWidth(emptyTrashAction.text))
        : actions.reduce(function(width, action) {
        return Math.max(width, labelMetrics.advanceWidth(action.name))
    }, Math.max(labelMetrics.advanceWidth(configureAction.text), dockBackground
        ? Math.max(labelMetrics.advanceWidth(qsTr("Position on Screen")),
            labelMetrics.advanceWidth(qsTr("Minimize Windows Using")), labelMetrics.advanceWidth(qsTr("Automatically Hide Dock")))
        : 0))
    implicitWidth: (verticalTail ? pointerHeight : 0) + Math.max(Kirigami.Units.gridUnit * (trashItem ? 8 : 12),
        labelWidth + Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 6 + contentPadding * 2,
        recentContent.visible ? Math.min(recentContent.implicitWidth, Kirigami.Units.gridUnit * 24) + contentPadding * 2 : 0,
        placesContent.visible ? placesContent.implicitWidth + contentPadding * 2 : 0,
        dockBackground ? dockAutoHideAction.implicitWidth + contentPadding * 2 : 0,
        mediaContent.visible ? mediaContent.implicitWidth + contentPadding * 2 : 0,
        canLaunchNewWindow ? newWindowAction.implicitWidth + contentPadding * 2 : 0,
        canPin ? pinAction.implicitWidth + contentPadding * 2 : 0,
        pinned && !trashItem ? unpinAction.implicitWidth + contentPadding * 2 : 0,
        trashItem ? emptyTrashAction.implicitWidth + contentPadding * 2 : 0)
    FontMetrics { id: labelMetrics; font: configureAction.font }
    implicitHeight: rows.implicitHeight + contentPadding * 2 + (verticalTail ? 0 : pointerHeight)
    width: implicitWidth
    height: implicitHeight

    function focusFirst() {
        if (root.trashItem) openTrashAction.forceActiveFocus(Qt.PopupFocusReason)
        else if (root.folderItem && root.folderSortNameAction)
            root.folderSortNameAction.forceActiveFocus(Qt.PopupFocusReason)
        else if (root.dockBackground && root.settings) dockAutoHideAction.forceActiveFocus(Qt.PopupFocusReason)
        else configureAction.forceActiveFocus(Qt.PopupFocusReason)
    }
    Keys.onEscapePressed: root.closeRequested()

    BalloonSurface {
        id: surface
        objectName: "dockContextSurface"
        anchors.fill: parent
        pointerX: root.pointerX
        pointerY: root.pointerY
        tailEdge: root.tailEdge
        tailHeight: root.pointerHeight
    }
    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.leftMargin: root.contentPadding + (root.tailEdge === "left" ? root.pointerHeight : 0)
        anchors.rightMargin: root.contentPadding + (root.tailEdge === "right" ? root.pointerHeight : 0)
        anchors.topMargin: root.contentPadding
        anchors.bottomMargin: root.contentPadding + (root.verticalTail ? 0 : root.pointerHeight)
        spacing: Kirigami.Units.smallSpacing
        DockContextSectionHeader {
            visible: root.folderItem
            text: qsTr("Sort by")
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                {mode: "name", label: qsTr("Name")},
                {mode: "size", label: qsTr("Size")},
                {mode: "modified", label: qsTr("Date Modified")},
                {mode: "created", label: qsTr("Date Created")},
                {mode: "kind", label: qsTr("Type")}
            ]
            delegate: DockContextAction {
                id: folderSortOption
                required property var modelData
                objectName: "folderSort-" + modelData.mode
                Layout.fillWidth: true
                visible: root.folderItem
                text: modelData.label
                marked: !!root.folderContainer && root.folderContainer.sortMode === modelData.mode
                onClicked: root.folderSortRequested(modelData.mode)
                Component.onCompleted: if (modelData.mode === "name") root.folderSortNameAction = folderSortOption
            }
        }
        DockContextSectionHeader {
            visible: root.folderItem
            text: qsTr("View content as")
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                {mode: "grid", label: qsTr("Grid")},
                {mode: "list", label: qsTr("List")},
                {mode: "detail", label: qsTr("Detail")}
            ]
            delegate: DockContextAction {
                required property var modelData
                objectName: "folderLayout-" + modelData.mode
                Layout.fillWidth: true
                visible: root.folderItem
                text: modelData.label
                marked: !!root.folderContainer && root.folderContainer.layout === modelData.mode
                onClicked: root.folderLayoutRequested(modelData.mode)
            }
        }
        DockContextAction {
            objectName: "openFolderAction"
            Layout.fillWidth: true
            visible: root.folderItem
            text: root.folderContainer && root.folderContainer.title.length > 0
                ? qsTr("Open “%1”").arg(root.folderContainer.title) : qsTr("Open Downloads")
            icon.name: "document-open-folder"
            onClicked: root.openFolderRequested()
        }
        DockContextAction {
            id: openTrashAction
            objectName: "openTrashAction"
            Layout.fillWidth: true
            visible: root.trashItem
            text: qsTr("Open")
            icon.name: "document-open"
            onClicked: root.openTrashRequested()
        }
        DockContextSeparator { visible: root.trashItem; Layout.fillWidth: true }
        DockContextAction {
            id: emptyTrashAction
            objectName: "emptyTrashAction"
            Layout.fillWidth: true
            visible: root.trashItem
            enabled: root.canEmptyTrash
            text: qsTr("Empty Trash")
            icon.name: "edit-delete"
            onClicked: root.emptyTrashRequested()
        }
        DockContextMedia {
            id: mediaContent
            objectName: "dockContextMedia"
            Layout.fillWidth: true
            media: root.media
            visible: available
            onCommandRequested: function(command) { root.mediaCommandRequested(command) }
        }
        DockContextPlaces {
            id: placesContent
            Layout.fillWidth: true
            places: root.places
            visible: root.usesPlaces
            onOpenRequested: function(resource) { root.placeRequested(resource) }
            onMoreRequested: root.morePlacesRequested()
            onGroupRequested: function(group) { root.placesGroupRequested(group) }
            onBackRequested: root.placesBackRequested()
        }
        DockContextRecentFiles {
            id: recentContent
            Layout.fillWidth: true
            documents: root.recentDocuments
            visible: !root.usesPlaces && count > 0
            onOpenRequested: function(resource) { root.recentRequested(resource) }
            onForgetRequested: root.forgetRecentRequested()
        }
        DockContextSectionHeader {
            visible: recentContent.visible || placesContent.visible
            text: qsTr("Actions")
            Layout.fillWidth: true
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(6, root.actions.length) * configureAction.implicitHeight
            visible: root.actions.length > 0
            clip: true
            ListView {
                model: root.actions
                boundsBehavior: Flickable.StopAtBounds
                delegate: DockContextAction {
                    id: desktopAction
                    required property var modelData
                    objectName: "desktopAction-" + modelData.actionId
                    width: ListView.view.width
                    height: implicitHeight
                    text: modelData.name
                    icon.name: modelData.icon || "system-run"
                    onClicked: root.actionRequested(modelData.actionId)
                }
            }
        }
        DockContextAction {
            id: newWindowAction
            objectName: "openNewWindowAction"
            Layout.fillWidth: true
            visible: root.canLaunchNewWindow
            text: qsTr("Open New Window")
            icon.name: "window-new"
            onClicked: root.newWindowRequested()
        }
        DockContextAction {
            id: pinAction
            objectName: "pinDockAction"
            Layout.fillWidth: true
            visible: root.canPin && !root.pinned && !root.trashItem && !root.dockBackground
            text: qsTr("Pin to Dock")
            icon.name: "window-pin"
            onClicked: root.pinRequested()
        }
        DockContextAction {
            id: unpinAction
            objectName: "unpinDockAction"
            Layout.fillWidth: true
            visible: root.pinned && !root.trashItem
            text: qsTr("Unpin from Dock")
            icon.name: "window-unpin"
            onClicked: root.unpinRequested()
        }
        DockContextSeparator {
            visible: !root.trashItem && (root.dockBackground || root.actions.length > 0 || root.canLaunchNewWindow
                || root.canPin || root.pinned || recentContent.visible || placesContent.visible)
            Layout.fillWidth: true
        }
        DockContextSectionHeader {
            visible: !root.trashItem && root.dockBackground
            text: qsTr("Dock")
            Layout.fillWidth: true
        }
        DockContextAction {
            id: dockAutoHideAction
            objectName: "dockAutoHideAction"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.settings
            text: qsTr("Automatically Hide Dock")
            icon.name: "visibility-hidden"
            marked: !!root.settings && root.settings.panelMode === "autohide"
            onClicked: root.autoHideRequested()
        }
        DockContextAction {
            objectName: "dockMagnificationAction"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.settings
            text: qsTr("Magnification")
            icon.name: "zoom-in"
            marked: !!root.settings && root.settings.magnificationEnabled
            onClicked: root.magnificationRequested()
        }
        DockContextAction {
            id: dockPositionSubmenu
            objectName: "dockPositionSubmenu"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.settings
            text: qsTr("Position on Screen")
            icon.name: "transform-move"
            submenu: true
            onClicked: root.openDockSubmenu = root.openDockSubmenu === "position" ? "" : "position"
        }
        Repeater {
            model: [
                {edge: "left", label: qsTr("Left")},
                {edge: "bottom", label: qsTr("Bottom")},
                {edge: "right", label: qsTr("Right")}
            ]
            delegate: DockContextAction {
                required property var modelData
                objectName: "dockPosition-" + modelData.edge
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit
                visible: !root.trashItem && root.dockBackground && !!root.settings && root.openDockSubmenu === "position"
                text: modelData.label
                marked: !!root.settings && root.settings.dockEdge === modelData.edge
                onClicked: root.dockEdgeRequested(modelData.edge)
            }
        }
        DockContextAction {
            id: minimizeEffectSubmenu
            objectName: "minimizeEffectSubmenu"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.minimizeEffectController && root.minimizeEffectController.available
            text: qsTr("Minimize Windows Using")
            icon.name: "window-minimize"
            submenu: true
            onClicked: root.openDockSubmenu = root.openDockSubmenu === "minimize" ? "" : "minimize"
        }
        Repeater {
            model: [
                {effect: "none", label: qsTr("No Effect"), available: true},
                {effect: "squash", label: qsTr("Squash"), available: !!root.minimizeEffectController && root.minimizeEffectController.squashAvailable},
                {effect: "magiclamp", label: qsTr("Magic Lamp"), available: !!root.minimizeEffectController && root.minimizeEffectController.magicLampAvailable},
                {effect: "other", label: qsTr("Other"), available: !!root.minimizeEffectController && root.minimizeEffectController.effect === "other"}
            ]
            delegate: DockContextAction {
                required property var modelData
                objectName: "minimizeEffect-" + modelData.effect
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit
                visible: !root.trashItem && root.dockBackground && root.openDockSubmenu === "minimize"
                    && !!root.minimizeEffectController && modelData.available
                enabled: modelData.effect !== "other"
                text: modelData.label
                marked: !!root.minimizeEffectController && root.minimizeEffectController.effect === modelData.effect
                onClicked: root.minimizeEffectRequested(modelData.effect)
            }
        }
        DockContextAction {
            id: configureAction
            objectName: "configureDockAction"
            Layout.fillWidth: true
            visible: !root.trashItem
            text: qsTr("Configure Dock")
            icon.name: "preferences-system"
            onClicked: root.settingsRequested()
        }
    }
}
