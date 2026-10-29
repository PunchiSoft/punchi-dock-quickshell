// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../config"
import "../../components"

// Popup host of the recent-applications container. It mirrors the folder
// container plumbing: one anchor to the dock icon, a serial so a retarget never
// opens twice, the KWin blur confined to the surface, and the focus returned to
// the container item when the popup closes.
Popup {
    id: root
    property var hostWindow: null
    required property ShellSettings settings
    // RecentApplicationsModel the dock already filters by pinned and open items.
    required property var selection
    property string title: qsTr("Recent applications")
    property int openSerial: 0
    property bool preparingToShow: false
    // Reason the popup gives its first row. A pointer click must not paint a
    // keyboard band; Enter on a focused launcher must.
    property int openFocusReason: Qt.MouseFocusReason
    property real hostBaseHeight: hostWindow ? hostWindow.height : 0
    property real capturedBaseY: 0
    property string dockEdge: settings.dockEdge
    readonly property bool vertical: dockEdge !== "bottom"
    // The arc paints no surface, so it is placed from the glyph that faces the
    // panel instead of from the middle of a card.
    readonly property bool fanPresentation: content.viewMode === "fan"
    property alias contents: content
    property alias sourceItem: anchor.sourceItem
    signal activateRequested(string appId)
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

    PopupAnchor {
        id: anchor
        followRenderedIcon: root.visible || root.preparingToShow
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

    function toggleForItem(item: Item, fromKeyboard): void {
        if (visible || preparingToShow) { dismiss(); return }
        if (!anchor.captureItem(item, root.title)) return
        root.openFocusReason = fromKeyboard ? Qt.TabFocusReason : Qt.MouseFocusReason
        capturedBaseY = anchor.anchorGeometry.y - (hostWindow ? hostWindow.height - hostBaseHeight : 0)
        preparingToShow = true
        const serial = ++openSerial
        Qt.callLater(function() {
            if (serial !== root.openSerial) return
            if (!root.sourceItem || !root.sourceItem.visible) { root.dismiss(); return }
            root.open(); root.preparingToShow = false
        })
    }
    function dismiss(): void { ++openSerial; preparingToShow = false; close() }
    onSourceItemChanged: if (!sourceItem && (visible || preparingToShow)) dismiss()
    onOpened: content.requestInitialFocus(root.openFocusReason)
    onClosed: {
        if (sourceItem && sourceItem.visible && sourceItem.enabled)
            sourceItem.forceActiveFocus(Qt.PopupFocusReason)
    }
    contentItem: RecentApplicationsContent {
        id: content
        selection: root.selection
        // A vertical dock presents its stored fan as Grid without rewriting it.
        viewMode: root.settings.effectiveRecentApplicationsLayout
        title: root.title
        popupScale: root.settings.popupScale
        popupIconSize: root.settings.popupIconSize
        popupListIconSize: root.settings.popupListIconSize
        popupFanIconSize: root.settings.popupFanIconSize
        dockEdge: root.dockEdge
        surfaceVisible: root.visible
        reducedMotion: root.settings.effectiveReducedMotion
        maximumWidth: Math.max(1, (root.parent ? root.parent.width : Kirigami.Units.gridUnit * 36)
            - Kirigami.Units.largeSpacing * 2)
        maximumHeight: Math.max(1, Math.min(
            (root.parent ? root.parent.height : Kirigami.Units.gridUnit * 40)
                * root.settings.popupHeightPercent / 100,
            root.vertical ? (root.parent ? root.parent.height : Kirigami.Units.gridUnit * 30)
                : root.capturedBaseY + (root.hostWindow ? root.hostWindow.height - root.hostBaseHeight : 0)
                    - Kirigami.Units.smallSpacing))
        tailEdge: root.dockEdge === "left" ? "left" : root.dockEdge === "right" ? "right" : "bottom"
        pointerX: anchor.anchorGeometry.x + anchor.anchorGeometry.width / 2 - root.x
        pointerY: anchor.anchorGeometry.y + anchor.anchorGeometry.height / 2 - root.y
        blurAvailable: blurController.available
        onActivateRequested: function(appId) { root.activateRequested(appId) }
        onCloseRequested: root.dismiss()
    }
}
