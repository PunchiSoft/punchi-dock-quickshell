// SPDX-License-Identifier: GPL-3.0-or-later
// Shares the tooltip balloon silhouette with compact themed menu rows.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
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
    property bool pointerEmphasis: true

    // Exactly one row paints an emphasis band. Real pointer motion hands it to
    // the pointer; a keyboard focus move hands it back to the keyboard, so a
    // focused row and another hovered row never light up together.
    property point lastPointerPosition: Qt.point(-1, -1)
    HoverHandler {
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }
    // Window.activeFocusItem is typed as a bare item, so read the focus reason
    // through an untyped helper the linter can follow.
    function focusReasonOf(item): int {
        return item ? item["focusReason"] : Qt.OtherFocusReason
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const item = root.Window.activeFocusItem
            if (!item) return
            let ancestor = item
            while (ancestor && ancestor !== root) ancestor = ancestor.parent
            if (!ancestor) return
            const reason = root.focusReasonOf(item)
            root.pointerEmphasis = reason !== Qt.TabFocusReason
                && reason !== Qt.BacktabFocusReason && reason !== Qt.ShortcutFocusReason
        }
    }
    // Popup rows only fade and pulse when a loaded settings object confirms
    // motion is allowed; standalone fixtures keep the instant, final state.
    readonly property bool motionEnabled: root.settings
        ? !root.settings.effectiveReducedMotion : false
    property var minimizeEffectController: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool canPin: false
    property bool pinned: false
    property var windowActions: ({})
    property var virtualDesktops: []
    property bool trashItem: false
    property bool dockBackground: false
    property bool folderItem: false
    property var folderContainer: null
    // The recent-applications container shares the view section of a folder
    // container, but sorts nothing and opens no folder.
    property bool recentContainer: false
    property string recentContainerLayout: ""
    // Presentation the popup really shows, and whether the arc can be offered at
    // all: a vertical panel has no near row to unfold from.
    readonly property string folderLayout: {
        const stored = root.folderContainer && root.folderContainer.layout
            ? String(root.folderContainer.layout) : ""
        return stored === "fan" && root.settings && !root.settings.fanSupported
            ? "grid" : stored
    }
    readonly property bool fanAvailable: !root.settings || root.settings.fanSupported
    property Item folderSortNameAction: null
    property Item recentLayoutFirstAction: null
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
    signal windowActionRequested(string action, var virtualDesktop)
    signal settingsRequested()
    signal closeRequested()
    signal openTrashRequested()
    signal openFolderRequested()
    signal folderSortRequested(string sortMode)
    signal folderLayoutRequested(string layout)
    signal recentLayoutRequested(string layout)
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
        windowActionsContent.visible ? windowActionsContent.implicitWidth + contentPadding * 2 : 0,
        canLaunchNewWindow ? newWindowAction.implicitWidth + contentPadding * 2 : 0,
        canPin ? pinAction.implicitWidth + contentPadding * 2 : 0,
        pinned && !trashItem ? unpinAction.implicitWidth + contentPadding * 2 : 0,
        trashItem ? emptyTrashAction.implicitWidth + contentPadding * 2 : 0)
    FontMetrics { id: labelMetrics; font: configureAction.font }
    implicitHeight: rows.implicitHeight + contentPadding * 2 + (verticalTail ? 0 : pointerHeight)
    width: implicitWidth
    height: implicitHeight

    function focusFirst(reason) {
        if (reason === undefined) reason = Qt.MouseFocusReason
        // Opening with the pointer does not paint a band; the keyboard does.
        if (root.trashItem) openTrashAction.forceActiveFocus(reason)
        else if (root.recentContainer && root.recentLayoutFirstAction)
            root.recentLayoutFirstAction.forceActiveFocus(reason)
        else if (root.folderItem && root.folderSortNameAction)
            root.folderSortNameAction.forceActiveFocus(reason)
        else if (root.dockBackground && root.settings) dockAutoHideAction.forceActiveFocus(reason)
        else configureAction.forceActiveFocus(reason)
    }
    Keys.onEscapePressed: root.closeRequested()

    PunchiBalloonSurface {
        id: surface
        objectName: "dockContextSurface"
        anchors.fill: parent
        pointerX: root.pointerX
        pointerY: root.pointerY
        tailEdge: root.tailEdge
        tailHeight: root.pointerHeight
        cornerRadius: Kirigami.Units.cornerRadius * 2
    }
    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.leftMargin: root.contentPadding + (root.tailEdge === "left" ? root.pointerHeight : 0)
        anchors.rightMargin: root.contentPadding + (root.tailEdge === "right" ? root.pointerHeight : 0)
        anchors.topMargin: root.contentPadding
        anchors.bottomMargin: root.contentPadding + (root.verticalTail ? 0 : root.pointerHeight)
        spacing: Kirigami.Units.smallSpacing
        PunchiDockContextSectionHeader {
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
            delegate: PunchiDockContextAction {
                pointerEmphasis: root.pointerEmphasis
                id: folderSortOption
                motionEnabled: root.motionEnabled
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
        PunchiDockContextSectionHeader {
            visible: root.folderItem || root.recentContainer
            text: qsTr("View content as")
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                {mode: "grid", label: qsTr("Grid")},
                {mode: "list", label: qsTr("List")},
                {mode: "detail", label: qsTr("Detail")},
                {mode: "fan", label: qsTr("Fan")}
            ]
            delegate: PunchiDockContextAction {
                pointerEmphasis: root.pointerEmphasis
                motionEnabled: root.motionEnabled
                id: folderLayoutOption
                required property var modelData
                objectName: root.recentContainer
                    ? "recentLayout-" + modelData.mode : "folderLayout-" + modelData.mode
                Layout.fillWidth: true
                visible: root.folderItem || root.recentContainer
                enabled: modelData.mode !== "fan" || root.fanAvailable
                text: modelData.label
                marked: root.recentContainer
                    ? root.recentContainerLayout === modelData.mode
                    : !!root.folderContainer && root.folderLayout === modelData.mode
                onClicked: {
                    if (root.recentContainer) root.recentLayoutRequested(modelData.mode)
                    else root.folderLayoutRequested(modelData.mode)
                }
                Component.onCompleted: {
                    if (modelData.mode === "grid") root.recentLayoutFirstAction = folderLayoutOption
                }
            }
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            motionEnabled: root.motionEnabled
            objectName: "openFolderAction"
            Layout.fillWidth: true
            visible: root.folderItem
            text: root.folderContainer && root.folderContainer.title.length > 0
                ? qsTr("Open “%1”").arg(root.folderContainer.title) : qsTr("Open Downloads")
            icon.name: "document-open-folder"
            onClicked: root.openFolderRequested()
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: openTrashAction
            motionEnabled: root.motionEnabled
            objectName: "openTrashAction"
            Layout.fillWidth: true
            visible: root.trashItem
            text: qsTr("Open")
            icon.name: "document-open"
            onClicked: root.openTrashRequested()
        }
        PunchiDockContextSeparator { visible: root.trashItem; Layout.fillWidth: true }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: emptyTrashAction
            motionEnabled: root.motionEnabled
            objectName: "emptyTrashAction"
            Layout.fillWidth: true
            visible: root.trashItem
            enabled: root.canEmptyTrash
            text: qsTr("Empty Trash")
            icon.name: "edit-delete"
            onClicked: root.emptyTrashRequested()
        }
        PunchiDockContextMedia {
            pointerEmphasis: root.pointerEmphasis
            id: mediaContent
            motionEnabled: root.motionEnabled
            objectName: "dockContextMedia"
            Layout.fillWidth: true
            media: root.media
            visible: available
            onCommandRequested: function(command) { root.mediaCommandRequested(command) }
        }
        PunchiDockContextPlaces {
            pointerEmphasis: root.pointerEmphasis
            id: placesContent
            motionEnabled: root.motionEnabled
            Layout.fillWidth: true
            places: root.places
            visible: root.usesPlaces
            onOpenRequested: function(resource) { root.placeRequested(resource) }
            onMoreRequested: root.morePlacesRequested()
            onGroupRequested: function(group) { root.placesGroupRequested(group) }
            onBackRequested: root.placesBackRequested()
        }
        PunchiDockContextRecentFiles {
            pointerEmphasis: root.pointerEmphasis
            id: recentContent
            motionEnabled: root.motionEnabled
            Layout.fillWidth: true
            documents: root.recentDocuments
            visible: !root.usesPlaces && count > 0
            onOpenRequested: function(resource) { root.recentRequested(resource) }
            onForgetRequested: root.forgetRecentRequested()
        }
        PunchiDockContextSectionHeader {
            visible: recentContent.visible || placesContent.visible
            text: qsTr("Actions")
            Layout.fillWidth: true
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(6, root.actions.length) * configureAction.implicitHeight
            visible: root.actions.length > 0
            clip: true
            ScrollBar.vertical: PunchiPopupScrollBar { motionEnabled: root.motionEnabled }
            ListView {
                model: root.actions
                boundsBehavior: Flickable.StopAtBounds
                delegate: PunchiDockContextAction {
                    pointerEmphasis: root.pointerEmphasis
                    id: desktopAction
                    motionEnabled: root.motionEnabled
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
        PunchiDockContextWindowActions {
            pointerEmphasis: root.pointerEmphasis
            id: windowActionsContent
            motionEnabled: root.motionEnabled
            objectName: "dockWindowActions"
            Layout.fillWidth: true
            windowActions: root.windowActions
            virtualDesktops: root.virtualDesktops
            visible: !!root.windowActions.available
            onActionRequested: function(action, virtualDesktop) { root.windowActionRequested(action, virtualDesktop) }
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: newWindowAction
            motionEnabled: root.motionEnabled
            objectName: "openNewWindowAction"
            Layout.fillWidth: true
            visible: root.canLaunchNewWindow
            text: qsTr("Open New Window")
            icon.name: "window-new"
            onClicked: root.newWindowRequested()
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: pinAction
            motionEnabled: root.motionEnabled
            objectName: "pinDockAction"
            Layout.fillWidth: true
            visible: root.canPin && !root.pinned && !root.trashItem && !root.dockBackground
            text: qsTr("Pin to Dock")
            icon.name: "window-pin"
            onClicked: root.pinRequested()
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: unpinAction
            motionEnabled: root.motionEnabled
            objectName: "unpinDockAction"
            Layout.fillWidth: true
            visible: root.pinned && !root.trashItem
            text: qsTr("Unpin from Dock")
            icon.name: "window-unpin"
            onClicked: root.unpinRequested()
        }
        // Only divides rows that really exist above it; a leading separator would
        // sit alone under the surface border on the dock background menu.
        PunchiDockContextSeparator {
            objectName: "contextActionsSeparator"
            visible: !root.trashItem && (root.actions.length > 0 || root.canLaunchNewWindow
                || root.canPin || root.pinned || recentContent.visible || placesContent.visible)
            Layout.fillWidth: true
        }
        PunchiDockContextSectionHeader {
            visible: !root.trashItem && root.dockBackground
            text: qsTr("Dock")
            Layout.fillWidth: true
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: dockAutoHideAction
            motionEnabled: root.motionEnabled
            objectName: "dockAutoHideAction"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.settings
            text: qsTr("Automatically Hide Dock")
            icon.name: "visibility-hidden"
            marked: !!root.settings && root.settings.panelMode === "autohide"
            onClicked: root.autoHideRequested()
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            motionEnabled: root.motionEnabled
            objectName: "dockMagnificationAction"
            Layout.fillWidth: true
            visible: !root.trashItem && root.dockBackground && !!root.settings
            text: qsTr("Magnification")
            icon.name: "zoom-in"
            marked: !!root.settings && root.settings.magnificationEnabled
            onClicked: root.magnificationRequested()
        }
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: dockPositionSubmenu
            motionEnabled: root.motionEnabled
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
            delegate: PunchiDockContextAction {
                pointerEmphasis: root.pointerEmphasis
                motionEnabled: root.motionEnabled
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
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: minimizeEffectSubmenu
            motionEnabled: root.motionEnabled
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
            delegate: PunchiDockContextAction {
                pointerEmphasis: root.pointerEmphasis
                motionEnabled: root.motionEnabled
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
        PunchiDockContextAction {
            pointerEmphasis: root.pointerEmphasis
            id: configureAction
            motionEnabled: root.motionEnabled
            objectName: "configureDockAction"
            Layout.fillWidth: true
            visible: !root.trashItem
            text: qsTr("Configure Dock")
            icon.name: "preferences-system"
            onClicked: root.settingsRequested()
        }
    }
}
