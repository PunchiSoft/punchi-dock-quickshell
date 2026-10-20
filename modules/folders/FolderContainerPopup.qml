// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../config"
import "../dock"

Popup {
    id: root
    property var hostWindow: null
    required property ShellSettings settings
    property var opener: null
    // Folder container currently shown. An empty path means the built-in
    // Downloads location, which the native folder model resolves through
    // QStandardPaths.
    property string appId: ""
    property var container: null
    readonly property url containerLocation: {
        const path = container && container.path ? String(container.path) : ""
        return path.length > 0 ? "file://" + path : listing.downloadsUrl
    }
    readonly property string containerTitle: container && String(container.title).length > 0
        ? String(container.title) : qsTr("Downloads")
    Connections {
        target: root.settings
        // A changed path re-reads the container so an open popup follows it.
        function onContainersChanged() {
            if (root.appId.length === 0) return
            root.container = root.settings.container(root.appId)
            if (root.visible) navigator.begin()
        }
    }
    property string dockEdge: settings.dockEdge
    readonly property bool vertical: dockEdge !== "bottom"
    // The arc paints no surface, so it is placed from the glyph that faces the
    // panel instead of from the middle of a card.
    readonly property bool fanPresentation: content.viewMode === "fan"
    readonly property alias contents: listing
    readonly property alias controller: navigator
    property alias sourceItem: anchor.sourceItem
    property int openSerial: 0
    property bool preparingToShow: false
    property real hostBaseHeight: hostWindow ? hostWindow.height : 0
    property real capturedBaseY: 0
    parent: hostWindow ? hostWindow.contentItem : null
    popupType: Popup.Item
    focus: true
    modal: false; dim: false
    padding: 0; margins: 0
    background: null
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    x: Math.max(0, Math.min((parent ? parent.width : 0) - width,
        dockEdge === "left" ? anchor.anchorGeometry.x + anchor.anchorGeometry.width + Kirigami.Units.smallSpacing
            : dockEdge === "right" ? anchor.anchorGeometry.x - width - Kirigami.Units.smallSpacing
            : root.fanPresentation
                ? anchor.anchorGeometry.x + anchor.anchorGeometry.width / 2
                    - content.fanOriginIconCenterX
                : anchor.anchorGeometry.x + anchor.anchorGeometry.width / 2 - width / 2))
    y: vertical ? Math.max(0, Math.min((parent ? parent.height : 0) - height,
        anchor.anchorGeometry.y + anchor.anchorGeometry.height / 2 - height / 2))
        : Math.max(0, capturedBaseY + (hostWindow ? hostWindow.height - hostBaseHeight : 0)
            - height - Kirigami.Units.smallSpacing)
    Native.FolderContents {
        id: listing
        sortMode: root.container && ["name", "size", "modified", "created", "kind"].indexOf(root.container.sortMode) >= 0
            ? root.container.sortMode : "modified"
        // Entries the owner kept out of this container. An empty list shows the
        // folder as it is, so new files appear without another choice.
        hiddenEntries: root.container && Array.isArray(root.container.hiddenEntries)
            ? root.container.hiddenEntries : []
    }
    FolderNavigationController {
        id: navigator
        contents: listing
        opener: root.opener
        rootLocation: root.containerLocation
        rootTitle: root.containerTitle
        onOpenDispatched: root.dismiss()
        onOperationRejected: console.warn("Punchi Dock Quickshell: folder activation rejected")
    }
    DockContextAnchor {
        id: anchor
        followRenderedIcon: root.visible || root.preparingToShow
    }
    function toggleForItem(item: Item, appId: string, entry: var): void {
        if (visible || preparingToShow) { dismiss(); return }
        if (!anchor.captureItem(item, root.containerTitle)) return
        // Callers that only pass the anchor keep the built-in Downloads folder.
        root.appId = appId ? appId : ""
        root.container = entry ? entry : null
        capturedBaseY = anchor.anchorGeometry.y - (hostWindow ? hostWindow.height - hostBaseHeight : 0)
        preparingToShow = true
        const serial = ++openSerial
        navigator.begin()
        Qt.callLater(function() {
            if (serial !== root.openSerial) return
            if (!root.sourceItem || !root.sourceItem.visible) { root.dismiss(); return }
            root.open(); root.preparingToShow = false
        })
    }
    function dismiss(): void { ++openSerial; preparingToShow = false; close(); if (!visible) navigator.finish() }
    onSourceItemChanged: if (!sourceItem && (visible || preparingToShow)) dismiss()
    onOpened: content.requestInitialFocus()
    onClosed: {
        navigator.finish()
        if (sourceItem && sourceItem.visible && sourceItem.enabled)
            sourceItem.forceActiveFocus(Qt.PopupFocusReason)
    }
    Native.PopupBlurController {
        id: blurController
        // Popup.Item shares the dock's native window; hostWindow is the
        // Quickshell PanelWindow wrapper, not a QQuickWindow itself.
        window: root.parent ? root.parent.Window.window : null
        // A floating arc has no surface to blur: the effect would frost the
        // empty rectangle around the rows.
        enabled: root.visible && !root.fanPresentation
        geometry: Qt.rect(root.x, root.y, root.width, root.height)
        tailEdge: root.dockEdge === "left" ? "left" : root.dockEdge === "right" ? "right" : "bottom"
        pointer: Qt.point(content.pointerX, content.pointerY)
        tailExtent: content.tailExtent
        cornerRadius: content.cornerRadius
    }
    Connections {
        target: root.parent ? root.parent.Window.window : null
        function onActiveChanged() {
            if (root.visible && !root.parent.Window.active) root.dismiss()
        }
    }
    contentItem: FolderContainerContent {
        id: content
        controller: navigator
        // The arc needs a horizontal panel; a vertical one presents Grid without
        // rewriting the container's stored presentation.
        viewMode: root.container ? root.settings.effectiveContainerLayout(root.appId) : "grid"
        dockEdge: root.dockEdge
        surfaceVisible: root.visible
        browseSubfolders: root.container ? root.settings.containerBrowseSubfolders(root.appId) : true
        maximumWidth: Math.max(1, (root.parent ? root.parent.width : Kirigami.Units.gridUnit * 36) - Kirigami.Units.largeSpacing * 2)
        maximumHeight: Math.max(1, Math.min(
            (root.parent ? root.parent.height : Kirigami.Units.gridUnit * 40) * 0.8,
            root.vertical ? (root.parent ? root.parent.height : Kirigami.Units.gridUnit * 30)
                : root.capturedBaseY + (root.hostWindow ? root.hostWindow.height - root.hostBaseHeight : 0)
                    - Kirigami.Units.smallSpacing))
        tailEdge: root.dockEdge === "left" ? "left" : root.dockEdge === "right" ? "right" : "bottom"
        pointerX: anchor.anchorGeometry.x + anchor.anchorGeometry.width / 2 - root.x
        pointerY: anchor.anchorGeometry.y + anchor.anchorGeometry.height / 2 - root.y
        blurAvailable: blurController.available
        reducedMotion: root.settings.effectiveReducedMotion
        onCloseRequested: root.dismiss()
    }
}
