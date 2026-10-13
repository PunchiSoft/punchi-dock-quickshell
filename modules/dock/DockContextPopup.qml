// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Popup {
    id: root
    objectName: "dockContextMenu"
    property var hostWindow: null
    property real hostBaseHeight: hostWindow ? hostWindow.height : 0
    property alias sourceItem: geometry.sourceItem
    property alias itemName: geometry.itemName
    property alias capturedGeometry: geometry.capturedGeometry
    property real capturedBaseY: 0
    property string appId: ""
    property var actions: []
    property var recentDocuments: null
    property var places: null
    property var media: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool pinned: false
    property bool trashItem: false
    property bool canEmptyTrash: false
    property bool preparingToShow: false
    property int openSerial: 0
    readonly property Item mainItem: content
    // Only the transparent window allocation grows; the dock stays at its baseline.
    readonly property real topOverflow: visible || preparingToShow
        ? Math.max(0, implicitHeight + Kirigami.Units.smallSpacing - capturedBaseY) : 0
    signal settingsRequested()
    signal actionRequested(string appId, string actionId)
    signal mediaCommandRequested(string command)
    signal openTrashRequested()
    signal emptyTrashRequested()
    signal placeRequested(string resource)
    signal morePlacesRequested()
    signal placesGroupRequested(string group)
    signal placesBackRequested()
    signal recentRequested(string resource)
    signal forgetRecentRequested()
    signal newWindowRequested()
    signal unpinRequested()
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
        geometry.capturedGeometry.x + geometry.capturedGeometry.width / 2 - width / 2))
    y: capturedBaseY + (hostWindow ? hostWindow.height - hostBaseHeight : 0)
        - height - Kirigami.Units.smallSpacing
    onOpened: content.focusFirst()
    onClosed: {
        openSerial++
        preparingToShow = false
        if (sourceItem && sourceItem.visible && sourceItem.enabled)
            sourceItem.forceActiveFocus(Qt.PopupFocusReason)
    }
    DockContextAnchor { id: geometry }
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
        capturedBaseY = geometry.capturedGeometry.y
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
        usesPlaces: root.usesPlaces
        canLaunchNewWindow: root.canLaunchNewWindow
        pinned: root.pinned
        trashItem: root.trashItem
        canEmptyTrash: root.canEmptyTrash
        itemName: root.itemName
        pointerX: geometry.capturedGeometry.x + geometry.capturedGeometry.width / 2 - root.x
        onActionRequested: function(actionId) {
            root.actionRequested(root.appId, actionId)
            root.dismiss()
        }
        onCloseRequested: root.dismiss()
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
        // Dismiss before removing the anchor's model row.
        onUnpinRequested: { root.dismiss(); root.unpinRequested() }
        onSettingsRequested: { root.dismiss(); root.settingsRequested() }
    }
}
