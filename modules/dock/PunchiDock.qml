// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Punchi.Kde as Native
import "../../config"
import "../../services"
import "../../adapters/kde"
import "../folders"
import "../recent"

PanelWindow {
    id: root
    required property PunchiDockServices services
    readonly property PunchiShellSettings settings: root.services.settings
    readonly property PunchiShellSettings preferences: root.settings
    readonly property var applicationCatalog: root.services.applicationCatalog
    readonly property var recentApplications: root.services.recentApplications
    readonly property var updateNotice: root.services.updateNotice
    // Placement policy is injected by the host. A standalone dock (tests) keeps
    // the previous unconditional behavior.
    property var screenPolicy: null
    property var desktopPolicy: null
    property bool requestedVisible: true
    readonly property bool screenAllowed: screenPolicy && root.screen
        ? screenPolicy.allows(root.screen) : true
    readonly property bool desktopAllowed: desktopPolicy ? desktopPolicy.desktopAllowed : true
    readonly property bool activityAllowed: desktopPolicy ? desktopPolicy.activityAllowed : true
    readonly property bool policyAllowed: desktopPolicy ? desktopPolicy.allowed : true
    readonly property bool windowAllowed: requestedVisible && screenAllowed && policyAllowed
    property bool configuring: false
    PunchiDockConfigurationController { hostWindow: root; active: root.configuring
        visibilityProperty: "requestedVisible" }
    signal settingsRequested()
    signal applicationLaunchFinished(string desktopId, bool success, string error)

    // The user-close action unmaps the window. Placement policy keeps the
    // surface mapped and opaque-free, so Quickshell never sees the last
    // window close while a desktop or screen is excluded.
    visible: root.requestedVisible

    readonly property bool vertical: root.settings.dockEdge === "left" || root.settings.dockEdge === "right"
    readonly property real baseLength: view.itemCount * root.settings.itemSize
        + Math.max(0, view.itemCount - 1) * root.settings.spacing + root.settings.padding * 2
    readonly property real edgeClearance: visibilityController.edgeMode ? root.settings.edgeMargin : 0
    Connections {
        target: root.settings
        function onDockEdgeChanged() {
            contextMenu.dismiss()
            folderPopup.dismiss()
            recentPopup.dismiss()
            visibilityController.reveal()
        }
    }
    // Coexist with Plasma and respect its reserved screen space.
    anchors.bottom: root.windowAllowed
    anchors.top: root.vertical && root.windowAllowed
    anchors.left: root.windowAllowed && root.settings.dockEdge === "left"
    anchors.right: root.windowAllowed && root.settings.dockEdge === "right"
    exclusiveZone: root.windowAllowed ? panelPolicy.exclusiveZone : 0
    exclusionMode: !root.windowAllowed || visibilityController.edgeMode
        ? ExclusionMode.Ignore : ExclusionMode.Normal
    margins.bottom: !root.vertical && !visibilityController.edgeMode ? root.settings.edgeMargin : 0
    margins.left: root.settings.dockEdge === "left" && !visibilityController.edgeMode ? root.settings.edgeMargin : 0
    margins.right: root.settings.dockEdge === "right" && !visibilityController.edgeMode ? root.settings.edgeMargin : 0
    implicitWidth: root.windowAllowed
        ? (root.screen ? root.screen.width : view.implicitWidth) : 1
    readonly property real dockAllocationHeight: (root.vertical ? view.implicitWidth : view.implicitHeight)
        + root.edgeClearance
    readonly property real slideDistance: slideGeometry.distance
    PunchiDockSlideGeometry { id: slideGeometry }
    // Opposite main-axis anchors let KWin supply the usable vertical extent.
    // The visible dock stays compact and centered inside this masked allocation.
    implicitHeight: !root.windowAllowed ? 1
        : root.vertical && root.screen ? root.screen.height : windowGeometry.windowHeight
    color: "transparent"
    // Stable transparent allocation must not intercept input in the surrounding desktop.
    mask: Region {
        Region {
            x: root.windowAllowed ? Math.floor(inputArea.x) : 0
            y: root.windowAllowed ? Math.floor(inputArea.y) : 0
            width: root.windowAllowed ? Math.ceil(inputArea.width) : 0
            height: root.windowAllowed ? Math.ceil(inputArea.height) : 0
        }
        Region {
            x: root.windowAllowed ? Math.floor(contextMenu.x) : 0
            y: root.windowAllowed ? Math.floor(contextMenu.y) : 0
            width: root.windowAllowed && contextMenu.visible ? Math.ceil(contextMenu.width) : 0
            height: root.windowAllowed && contextMenu.visible ? Math.ceil(contextMenu.height) : 0
        }
        Region {
            x: root.windowAllowed ? Math.floor(folderPopup.x) : 0
            y: root.windowAllowed ? Math.floor(folderPopup.y) : 0
            width: root.windowAllowed && folderPopup.visible ? Math.ceil(folderPopup.width) : 0
            height: root.windowAllowed && folderPopup.visible ? Math.ceil(folderPopup.height) : 0
        }
        Region {
            x: root.windowAllowed ? Math.floor(recentPopup.x) : 0
            y: root.windowAllowed ? Math.floor(recentPopup.y) : 0
            width: root.windowAllowed && recentPopup.visible ? Math.ceil(recentPopup.width) : 0
            height: root.windowAllowed && recentPopup.visible ? Math.ceil(recentPopup.height) : 0
        }
    }
    onVisibleChanged: if (!visible) { contextMenu.dismiss(); folderPopup.dismiss(); recentPopup.dismiss(); trash.cancel() }
    onWindowAllowedChanged: if (!root.windowAllowed) {
        contextMenu.dismiss()
        folderPopup.dismiss()
        recentPopup.dismiss()
        trash.cancel()
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dock"
    WlrLayershell.keyboardFocus: dockFocusPolicy.acceptsKeyboard
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    PunchiDockFocusPolicy {
        id: dockFocusPolicy
        surfaceVisible: visibilityController.surfaceVisible && root.windowAllowed
        menuOpen: view.contextMenuOpen || recentPopup.visible || recentPopup.preparingToShow
        keyboardNavigationRequested: view.keyboardNavigationRequested
    }

    PunchiDockWindowGeometry {
        id: windowGeometry
        baseHeight: root.dockAllocationHeight
        screenHeight: root.screen ? (root.vertical ? root.screen.width : root.screen.height) : 0
        bottomMargin: visibilityController.edgeMode ? 0 : root.settings.edgeMargin
        edgeHeight: root.settings.metrics.borderWidth
        surfaceVisible: visibilityController.surfaceVisible && root.windowAllowed
    }
    PunchiDockVisibilityController {
        id: visibilityController
        autoHide: panelPolicy.effectiveMode === "autohide"
        dodgeWindows: panelPolicy.effectiveMode === "dodge-windows"
        overlapAvailable: overlap.available
        overlapping: overlap.overlapping
        showingDesktop: overlap.showingDesktop
        configuring: root.configuring
        pointerInside: inputArea.hovered || nativeEdge.pointerInside
        menuOpen: view.contextMenuOpen || folderPopup.visible || folderPopup.preparingToShow
            || recentPopup.visible || recentPopup.preparingToShow || trashConfirmation.visible || trash.confirming || root.services.trashState.busy
        keyboardFocused: visibilityController.surfaceVisible && view.keyboardFocused && view.Window.active
        reducedMotion: root.settings.effectiveReducedMotion
        transitionDuration: root.settings.slideDuration
        onHiding: slideGeometry.capture(visibilityController.boundedSlideProgress,
            view.measureSlideTravelHeight() + root.settings.edgeMargin)
        onRevealing: slideGeometry.capture(visibilityController.boundedSlideProgress,
            view.measureSlideTravelHeight() + root.settings.edgeMargin)
    }
    Native.AutoHideEdge {
        id: nativeEdge
        edge: root.settings.dockEdge
        retainPointer: true
        enabled: root.windowAllowed && visibilityController.edgeMode
        armed: enabled && !visibilityController.surfaceVisible
        width: root.vertical ? Math.max(2, root.settings.metrics.padding) : root.baseLength
        height: root.vertical ? Math.min(root.baseLength, root.screen ? root.screen.height : root.baseLength)
            : Math.max(2, root.settings.metrics.padding)
        screenName: root.screen ? root.screen.name : ""
        onRevealRequested: visibilityController.reveal()
    }
    PunchiDockInputArea {
        id: inputArea
        objectName: "dock-input-area"
        dockEdge: root.settings.dockEdge
        edgeLength: root.baseLength
        hostWidth: root.width
        hostHeight: root.height
        contentBounds: Qt.rect(view.x + view.interactionBounds.x,
            view.y + view.interactionBounds.y, view.interactionBounds.width,
            view.interactionBounds.height)
        surfaceVisible: visibilityController.surfaceVisible
        nativeEdgeAvailable: nativeEdge.available
        enabled: root.windowAllowed && visibilityController.edgeMode
        onEntered: visibilityController.reveal()
    }
    PunchiDockPanelPolicy {
        id: panelPolicy
        mode: root.settings.panelMode
        edgeTriggerAvailable: !(root.settings.avoidInnerEdgeAutoHide && root.screenPolicy
            && root.screenPolicy.isSharedEdge(root.screen, root.settings.dockEdge))
        baseHeight: (view.itemCount > 0 ? view.itemSize : 0) + view.padding
            + (root.vertical ? view.padding : view.bottomContentPadding)
        // The compositor also accounts for the selected edge margin. Never reserve
        // the transparent inward allocation used by wave, bounce and balloons.
        bottomClearance: view.waveBottomReserve
    }
    // One command surface lives in PunchiDockIpc; this window only reports its state.
    function snapshot(): string {
        return JSON.stringify({
            mode: panelPolicy.effectiveMode,
            edge: root.settings.dockEdge,
            vertical: root.vertical,
            windowWidth: root.width,
            screenWidth: root.screen ? root.screen.width : 0,
            dockViewX: view.x,
            dockViewWidth: view.width,
            dockViewHeight: view.height,
            dockItemCount: view.itemCount,
            dockViewVisible: view.visible,
            dockViewOpacity: view.opacity,
            visible: root.visible,
            backingWindowVisible: root.backingWindowVisible,
            requestedVisible: root.requestedVisible,
            screenName: root.screen ? root.screen.name : "",
            screenAllowed: root.screenAllowed,
            desktopAllowed: root.desktopAllowed,
            activityAllowed: root.activityAllowed,
            policyAllowed: root.policyAllowed,
            windowAllowed: root.windowAllowed,
            desktopAvailable: root.desktopPolicy ? root.desktopPolicy.available : false,
            currentDesktopId: root.desktopPolicy ? root.desktopPolicy.currentDesktopId : "",
            currentActivityId: root.desktopPolicy ? root.desktopPolicy.currentActivityId : "",
            layer: root.WlrLayershell.layer,
            exclusiveZone: root.exclusiveZone,
            baseHeight: panelPolicy.baseHeight,
            windowHeight: root.height,
            surfaceVisible: visibilityController.surfaceVisible,
            opacity: visibilityController.opacity,
            slideProgress: visibilityController.boundedSlideProgress,
            slideOffset: root.vertical ? slideTransform.x : slideTransform.y,
            sceneX: view.mapToItem(null, 0, 0).x,
            sceneY: view.mapToItem(null, 0, 0).y,
            restingSceneY: view.y,
            slideDistance: root.slideDistance,
            nativeEdgeAvailable: nativeEdge.available,
            nativeEdgePointerInside: nativeEdge.pointerInside,
            dockPointerInside: inputArea.hovered,
            inputBounds: Qt.rect(inputArea.x, inputArea.y, inputArea.width, inputArea.height),
            overlapAvailable: overlap.available,
            overlapping: overlap.overlapping,
            showingDesktop: overlap.showingDesktop,
            restingRegion: restingGeometry.region,
            reducedMotion: root.settings.effectiveReducedMotion
        })
    }
    function reveal(): bool {
        if (!root.screenAllowed || !root.policyAllowed) return false
        root.requestedVisible = true
        visibilityController.reveal()
        return true
    }
    function focus(): bool {
        if (!root.reveal()) return false
        return view.focusItem(Math.max(0, view.currentIndex))
    }
    PunchiTrashService {
        id: trash
        state: root.services.trashState
        launcher: contextApplicationAdapter
        onOperationRejected: console.warn("Punchi Dock Quickshell: trash operation rejected")
    }
    Connections {
        target: root.services.trashState
        function onOperationFinished(success, error): void {
            if (!success) console.warn("Punchi Dock Quickshell: empty trash failed:", error)
        }
    }
    PunchiTrashConfirmationWindow {
        id: trashConfirmation
        service: trash
        questionText: qsTr("Do you want to permanently delete all items in the Trash?")
        warningText: qsTr("This action cannot be undone.")
        reducedMotion: root.settings.effectiveReducedMotion
    }
    PunchiDockRestingGeometry {
        id: restingGeometry
        dockEdge: root.settings.dockEdge
        screenX: root.screen ? root.screen.x : 0
        screenY: root.screen ? root.screen.y : 0
        screenWidth: root.screen ? root.screen.width : 0
        screenHeight: root.screen ? root.screen.height : 0
        bodyWidth: root.vertical ? panelPolicy.baseHeight : root.baseLength
        bodyHeight: root.vertical ? Math.min(root.baseLength + view.bottomContentPadding,
            root.screen ? root.screen.height : root.baseLength + view.bottomContentPadding) : panelPolicy.baseHeight
        bottomClearance: view.waveBottomReserve
        edgeMargin: root.settings.edgeMargin
    }
    PunchiWindowOverlap {
        id: overlap
        source: root.services.runningApplications.visibilityState
        region: restingGeometry.region
    }

    PunchiDesktopApplicationAdapter {
        id: applicationAdapter
        activationItem: view
    }
    PunchiDesktopApplicationAdapter {
        id: contextApplicationAdapter
        // The anchor must live in the dock window that received the input. A
        // popup content item has no window until its own surface opens, so
        // anchoring to the context menu refused every folder activation and
        // every location opened from the folder popup while the menu was
        // closed. The window content item is always in the scene.
        activationItem: root.contentItem
    }
    PunchiApplicationLaunchService {
        id: contextLauncher
        entries: root.services.dockItems
        adapter: contextApplicationAdapter
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: desktop action rejected:", appId)
        }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: desktop action failed:", desktopId, error)
        }
    }

    PunchiApplicationActivationService {
        id: activation
        entries: root.services.dockItems
        launcher: launcher
        newWindowLauncher: newInstanceLauncher
        windowState: root.services.runningApplications
        onActivationRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: window activation rejected:", appId)
        }
    }
    PunchiDockContextPopup {
        id: contextMenu
        settings: root.settings
        minimizeEffectController: root.services.minimizeEffects
        dockEdge: root.settings.dockEdge
        hostWindow: root
        hostBaseHeight: root.vertical ? root.height : root.dockAllocationHeight
        actions: contextService.actions
        recentDocuments: contextService.recentDocuments
        places: contextService.places
        media: contextService.media
        usesPlaces: contextService.usesPlaces
        canLaunchNewWindow: contextService.canLaunchNewWindow
        canPin: contextService.canPin
        pinned: contextService.pinned
        windowActions: root.services.runningApplications.revision >= 0 ? root.services.runningApplications.windowActions(contextMenu.appId) : ({})
        virtualDesktops: root.services.runningApplications.virtualDesktops
        trashItem: contextMenu.appId === "item:trash"
        canEmptyTrash: trash.canEmpty
        onSettingsRequested: root.settingsRequested()
        onActionRequested: function(appId, actionId) { contextLauncher.launchAction(appId, actionId) }
        onPlaceRequested: function(resource) { contextService.openPlace(resource) }
        onMorePlacesRequested: contextService.showMorePlaces()
        onPlacesGroupRequested: function(group) { contextService.enterPlacesGroup(group) }
        onPlacesBackRequested: contextService.leavePlacesGroup()
        onRecentRequested: function(resource) { contextService.openRecent(resource) }
        onForgetRecentRequested: contextService.forgetRecent()
        onNewWindowRequested: contextService.openNewWindow()
        onPinRequested: contextService.pin()
        onUnpinRequested: contextService.unpin()
        onWindowActionRequested: function(action, virtualDesktop) {
            if (root.services.runningApplications.windowActivation.requestWindowAction(contextMenu.appId, action, virtualDesktop) === 0)
                console.warn("Punchi Dock Quickshell: window action request rejected:", action)
        }
        onMediaCommandRequested: function(command) { contextService.controlMedia(command) }
        onFolderSortRequested: function(appId, sortMode) { root.settings.setContainerSortMode(appId, sortMode) }
        onFolderLayoutRequested: function(appId, layout) { root.settings.setContainerLayout(appId, layout) }
        onRecentLayoutRequested: function(layout) { root.settings.recentApplicationsContainerLayout = layout }
        onOpenFolderRequested: {
            const entry = root.settings.container(contextMenu.appId)
            if (entry && entry.path.length > 0) contextApplicationAdapter.openFolderPath(entry.path)
            else if (entry && entry.id === "home") contextApplicationAdapter.openHome()
            else contextApplicationAdapter.openDownloads()
        }
        onOpenTrashRequested: trash.open()
        onEmptyTrashRequested: trash.requestEmpty()
        onAutoHideRequested: root.settings.panelMode = root.settings.panelMode === "autohide" ? "overlay" : "autohide"
        onMagnificationRequested: root.settings.magnificationEnabled = !root.settings.magnificationEnabled
        onDockEdgeRequested: function(edge) { root.settings.dockEdge = edge }
        onMinimizeEffectRequested: function(effect) {
            if (!root.services.minimizeEffects.setEffect(effect)) console.warn("Punchi Dock Quickshell: KWin minimize effect update failed")
        }
    }
    PunchiApplicationContextService {
        id: contextService
        entries: root.services.dockItems
        adapter: contextApplicationAdapter
        settings: root.preferences
        onRequestRejected: function(appId) { console.warn("Punchi Dock Quickshell: context request rejected:", appId) }
    }
    PunchiApplicationLaunchService {
        id: launcher
        entries: root.services.dockItems
        adapter: applicationAdapter
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: KDE application launch failed:", desktopId, error)
            root.applicationLaunchFinished(desktopId, success, error)
        }
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: application activation rejected:", appId)
        }
    }
    PunchiDesktopApplicationAdapter { id: newInstanceAdapter; activationItem: view }
    PunchiApplicationLaunchService {
        id: newInstanceLauncher
        entries: root.services.dockItems
        adapter: newInstanceAdapter
        onLaunchRejected: function(appId) { console.warn("Punchi Dock Quickshell: new window rejected:", appId) }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: new window failed:", desktopId, error)
        }
    }
    Connections {
        target: launcher
        function onLaunchDispatched(appId) { root.recentApplications.recordAccess(appId) }
    }
    Connections {
        target: contextLauncher
        function onLaunchDispatched(appId) { root.recentApplications.recordAccess(appId) }
    }
    Connections {
        target: newInstanceLauncher
        function onLaunchDispatched(appId) { root.recentApplications.recordAccess(appId) }
    }
    Connections {
        target: activation
        function onActivationDispatched(appId) { root.recentApplications.recordAccess(appId) }
    }
    PunchiDesktopApplicationAdapter { id: recentApplicationAdapter; activationItem: view }
    // The container lists entries the dock row no longer carries, so the popup
    // launches through the selection itself and still records the access.
    PunchiApplicationLaunchService {
        id: recentLauncher
        entries: root.recentApplications.selection
        adapter: recentApplicationAdapter
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: recent application activation rejected:", appId)
        }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: recent application launch failed:", desktopId, error)
        }
    }
    Connections {
        target: recentLauncher
        function onLaunchDispatched(appId) { root.recentApplications.recordAccess(appId) }
    }

    PunchiFolderContainerPopup {
        id: folderPopup
        objectName: "downloadsPopup"
        hostWindow: root
        hostBaseHeight: root.dockAllocationHeight
        settings: root.preferences
        opener: contextApplicationAdapter
        clipboardService: root.services.clipboard
    }
    Connections {
        target: root.settings
        function onPinnedIdsChanged() {
            if (!root.settings.container(folderPopup.appId)) folderPopup.dismiss()
        }
    }
    PunchiRecentApplicationsPopup {
        id: recentPopup
        objectName: "recentApplicationsPopup"
        hostWindow: root
        hostBaseHeight: root.dockAllocationHeight
        settings: root.preferences
        selection: root.recentApplications.selection
        onActivateRequested: function(appId) {
            recentLauncher.launch(appId)
            recentPopup.dismiss()
        }
    }
    Connections {
        target: root.settings
        // Either choice rebuilds the dock row; an open popup would then point at
        // an item that is gone.
        function onRecentApplicationsPresentationChanged() { recentPopup.dismiss() }
        function onRecentApplicationsEnabledChanged() { recentPopup.dismiss() }
    }
    PunchiDockView {
        id: view
        objectName: "dock-view"
        applicationState: root.services.runningApplications
        updateState: root.updateNotice
        contextMenuOpen: contextMenu.visible || contextMenu.preparingToShow
            || folderPopup.visible || folderPopup.preparingToShow
            || recentPopup.visible || recentPopup.preparingToShow
        onContextMenuRequested: function(sourceItem, appId, title, position) {
            folderPopup.dismiss()
            recentPopup.dismiss()
            contextMenu.appId = appId
            contextService.select(appId)
            if (appId.length > 0) contextMenu.openForItem(sourceItem, title)
            else contextMenu.openAt(sourceItem, position)
        }
        dockEdge: root.settings.dockEdge
        sceneTranslation: Qt.point(slideTransform.x, slideTransform.y)
        availableLength: root.vertical ? root.height : 0
        width: implicitWidth
        height: implicitHeight
        x: root.settings.dockEdge === "right" ? root.width - width - root.edgeClearance
            : root.vertical ? root.edgeClearance : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 + view.contentCenterOffset
            : root.height - height - root.edgeClearance
        visible: root.windowAllowed && visibilityController.surfaceVisible
        opacity: root.windowAllowed ? visibilityController.opacity : 0
        transform: Translate {
            id: slideTransform
            x: visibilityController.edgeMode && root.vertical
                ? (root.settings.dockEdge === "left" ? -1 : 1)
                    * (1 - visibilityController.boundedSlideProgress) * root.slideDistance : 0
            y: visibilityController.edgeMode && !root.vertical
                ? (1 - visibilityController.boundedSlideProgress) * root.slideDistance : 0
        }
        entries: root.services.dockItems
        itemSize: root.settings.itemSize
        iconSize: root.settings.iconSize
        itemSpacing: root.settings.spacing
        padding: root.settings.padding
        surfaceRadius: root.settings.surfaceRadius
        bottomContentPadding: root.settings.bottomContentPadding
        magnificationEnabled: root.settings.magnificationEnabled
        reducedMotion: root.settings.effectiveReducedMotion
        maximumIconScale: root.settings.maximumIconScale
        waveEnterDuration: root.settings.waveEnterDuration
        waveLeaveDuration: root.settings.waveLeaveDuration
        clickDuration: root.settings.clickDuration
        onSettingsRequested: root.settingsRequested()
        onItemActivated: function(appId) {
            contextMenu.dismiss()
            const container = root.settings.container(appId)
            const tile = view.itemForId(appId)
            // Enter on a focused launcher keeps its band; a pointer click does not
            // turn the first row into a keyboard row.
            const fromKeyboard = view.keyboardActivation(tile)
            if (container) folderPopup.toggleForItem(tile, appId, container, fromKeyboard)
            else if (appId === "item:recent") recentPopup.toggleForItem(tile, fromKeyboard)
            else {
                folderPopup.dismiss()
                recentPopup.dismiss()
                if (appId === "item:trash") trash.open()
                else activation.activate(appId)
            }
        }
        onItemNewWindowRequested: function(appId) {
            folderPopup.dismiss()
            recentPopup.dismiss()
            if (!appId.startsWith("item:")) activation.newWindow(appId)
            contextMenu.dismiss()
        }
        onCloseRequested: if (!root.configuring) root.requestedVisible = false
    }
}
