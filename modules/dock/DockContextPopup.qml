// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "../../components"

Popup {
    id: root
    objectName: "dockContextMenu"
    property string dockEdge: "bottom"
    readonly property bool vertical: dockEdge === "left" || dockEdge === "right"
    property var hostWindow: null
    property real hostBaseHeight: hostWindow ? hostWindow.height : 0
    property alias sourceItem: geometry.sourceItem
    property alias itemName: geometry.itemName
    property alias capturedGeometry: geometry.capturedGeometry
    property real capturedBaseY: 0
    property string appId: ""
    readonly property bool dockBackground: appId.length === 0
    property var settings: null
    readonly property var folderContainer: settings ? settings.container(appId) : null
    // The recent-applications container is not a stored folder; it only shares
    // the view choices.
    readonly property bool recentContainer: appId === "item:recent"
    readonly property string recentContainerLayout: settings
        ? settings.effectiveRecentApplicationsLayout : ""
    property var actions: []
    property var recentDocuments: null
    property var places: null
    property var media: null
    property var minimizeEffectController: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool canPin: false
    property bool pinned: false
    property var windowActions: ({})
    property var virtualDesktops: []
    property bool trashItem: false
    property bool canEmptyTrash: false
    property bool preparingToShow: false
    property int openSerial: 0
    readonly property Item mainItem: content
    // Only the transparent window allocation grows; the dock stays at its baseline.
    readonly property real topOverflow: !vertical && (visible || preparingToShow)
        ? Math.max(0, implicitHeight + Kirigami.Units.smallSpacing - capturedBaseY) : 0
    signal settingsRequested()
    signal actionRequested(string appId, string actionId)
    signal mediaCommandRequested(string command)
    signal openTrashRequested()
    signal openFolderRequested()
    signal folderSortRequested(string appId, string sortMode)
    signal folderLayoutRequested(string appId, string layout)
    signal recentLayoutRequested(string layout)
    signal emptyTrashRequested()
    signal autoHideRequested()
    signal magnificationRequested()
    signal dockEdgeRequested(string edge)
    signal minimizeEffectRequested(string effect)
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
    parent: hostWindow ? hostWindow.contentItem : null
    popupType: Popup.Item
    modal: false
    dim: false
    focus: true
    padding: 0
    margins: 0
    background: null
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    x: Math.max(0, Math.min((parent ? parent.width : 0) - width,
        dockEdge === "left" ? geometry.anchorGeometry.x + geometry.anchorGeometry.width + Kirigami.Units.smallSpacing
            : dockEdge === "right" ? geometry.anchorGeometry.x - width - Kirigami.Units.smallSpacing
            : geometry.anchorGeometry.x + geometry.anchorGeometry.width / 2 - width / 2))
    y: vertical ? Math.max(0, Math.min((parent ? parent.height : 0) - height,
        geometry.anchorGeometry.y + geometry.anchorGeometry.height / 2 - height / 2))
        : capturedBaseY + (hostWindow ? hostWindow.height - hostBaseHeight : 0)
            - height - Kirigami.Units.smallSpacing
    onOpened: content.focusFirst()
    onClosed: {
        openSerial++
        preparingToShow = false
        if (sourceItem && sourceItem.visible && sourceItem.enabled)
            sourceItem.forceActiveFocus(Qt.PopupFocusReason)
    }
    PopupAnchor {
        id: geometry
        followRenderedIcon: root.vertical && (root.visible || root.preparingToShow)
    }
    Connections {
        target: root.parent ? root.parent.Window.window : null
        function onActiveChanged() {
            if ((root.visible || root.preparingToShow) && !root.parent.Window.active) root.dismiss()
        }
    }
    function dismiss() {
        openSerial++
        preparingToShow = false
        close()
    }
    function openForItem(item: Item, title: string) {
        if (geometry.captureItem(item, title)) prepareOpen()
    }
    function openAt(item: Item, position: point) {
        if (geometry.capturePoint(item, position)) prepareOpen()
    }
    function prepareOpen() {
        capturedBaseY = geometry.anchorGeometry.y
            - (hostWindow ? hostWindow.height - hostBaseHeight : 0)
        const serial = ++openSerial
        preparingToShow = true
        Qt.callLater(function() {
            if (serial !== root.openSerial) return
            if (!root.sourceItem || !root.hostWindow) { root.preparingToShow = false; return }
            root.open()
            root.preparingToShow = false
            content.focusFirst()
        })
    }
    contentItem: DockContextContent {
        id: content
        actions: root.actions
        recentDocuments: root.recentDocuments
        places: root.places
        media: root.media
        settings: root.settings
        minimizeEffectController: root.minimizeEffectController
        usesPlaces: root.usesPlaces
        canLaunchNewWindow: root.canLaunchNewWindow
        canPin: root.canPin
        pinned: root.pinned
        windowActions: root.windowActions
        virtualDesktops: root.virtualDesktops
        trashItem: root.trashItem
        dockBackground: root.dockBackground
        folderItem: root.folderContainer !== null
        folderContainer: root.folderContainer
        recentContainer: root.recentContainer
        recentContainerLayout: root.recentContainerLayout
        canEmptyTrash: root.canEmptyTrash
        itemName: root.itemName
        tailEdge: root.dockEdge === "left" ? "left" : root.dockEdge === "right" ? "right" : "bottom"
        pointerY: geometry.anchorGeometry.y + geometry.anchorGeometry.height / 2 - root.y
        pointerX: geometry.anchorGeometry.x + geometry.anchorGeometry.width / 2 - root.x
        onActionRequested: function(actionId) {
            root.actionRequested(root.appId, actionId)
            root.dismiss()
        }
        onCloseRequested: root.dismiss()
        onOpenFolderRequested: { root.openFolderRequested(); root.dismiss() }
        onFolderSortRequested: function(sortMode) { root.folderSortRequested(root.appId, sortMode); root.dismiss() }
        onFolderLayoutRequested: function(layout) { root.folderLayoutRequested(root.appId, layout); root.dismiss() }
        onRecentLayoutRequested: function(layout) { root.recentLayoutRequested(layout); root.dismiss() }
        onOpenTrashRequested: { root.openTrashRequested(); root.dismiss() }
        onEmptyTrashRequested: { root.emptyTrashRequested(); root.dismiss() }
        onMediaCommandRequested: function(command) { root.mediaCommandRequested(command); root.dismiss() }
        onPlaceRequested: function(resource) { root.placeRequested(resource); root.dismiss() }
        onMorePlacesRequested: root.morePlacesRequested()
        onPlacesGroupRequested: function(group) { root.placesGroupRequested(group) }
        onPlacesBackRequested: root.placesBackRequested()
        onRecentRequested: function(resource) { root.recentRequested(resource); root.dismiss() }
        onForgetRecentRequested: { root.forgetRecentRequested(); root.dismiss() }
        onNewWindowRequested: { root.newWindowRequested(); root.dismiss() }
        onPinRequested: { root.dismiss(); root.pinRequested() }
        onWindowActionRequested: function(action, virtualDesktop) {
            root.dismiss()
            root.windowActionRequested(action, virtualDesktop)
        }
        // Dismiss before removing the anchor's model row.
        onUnpinRequested: { root.dismiss(); root.unpinRequested() }
        onSettingsRequested: { root.dismiss(); root.settingsRequested() }
        onAutoHideRequested: { root.dismiss(); root.autoHideRequested() }
        onMagnificationRequested: { root.dismiss(); root.magnificationRequested() }
        onDockEdgeRequested: function(edge) { root.dismiss(); root.dockEdgeRequested(edge) }
        onMinimizeEffectRequested: function(effect) { root.dismiss(); root.minimizeEffectRequested(effect) }
    }
}
