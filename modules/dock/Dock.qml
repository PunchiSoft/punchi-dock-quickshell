// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Punchi.Kde as Native
import "../../config"
import "../../services"
import "../../adapters/kde"
import "../folders"

PanelWindow {
    id: root
    property alias preferences: settings
    readonly property alias applicationCatalog: itemCatalog
    readonly property alias recentApplications: recentApplications
    readonly property alias updateNotice: updateNotice
    property bool configuring: false
    DockConfigurationController { hostWindow: root; active: root.configuring }
    signal settingsRequested()
    signal applicationLaunchFinished(string desktopId, bool success, string error)

    readonly property bool vertical: settings.dockEdge === "left" || settings.dockEdge === "right"
    readonly property real baseLength: view.itemCount * settings.itemSize
        + Math.max(0, view.itemCount - 1) * settings.spacing + settings.padding * 2
    readonly property real edgeClearance: visibilityController.edgeMode ? settings.edgeMargin : 0
    Connections {
        target: settings
        function onDockEdgeChanged() {
            contextMenu.dismiss()
            folderPopup.dismiss()
            visibilityController.reveal()
        }
    }
    // Coexist with Plasma and respect its reserved screen space.
    anchors.bottom: true
    anchors.top: root.vertical
    anchors.left: settings.dockEdge === "left"
    anchors.right: settings.dockEdge === "right"
    exclusiveZone: panelPolicy.exclusiveZone
    exclusionMode: visibilityController.edgeMode ? ExclusionMode.Ignore : ExclusionMode.Normal
    margins.bottom: !root.vertical && !visibilityController.edgeMode ? settings.edgeMargin : 0
    margins.left: settings.dockEdge === "left" && !visibilityController.edgeMode ? settings.edgeMargin : 0
    margins.right: settings.dockEdge === "right" && !visibilityController.edgeMode ? settings.edgeMargin : 0
    implicitWidth: root.screen ? root.screen.width : view.implicitWidth
    readonly property real dockAllocationHeight: (root.vertical ? view.implicitWidth : view.implicitHeight)
        + root.edgeClearance
    readonly property real slideDistance: slideGeometry.distance
    DockSlideGeometry { id: slideGeometry }
    // Opposite main-axis anchors let KWin supply the usable vertical extent.
    // The visible dock stays compact and centered inside this masked allocation.
    implicitHeight: root.vertical && root.screen ? root.screen.height : windowGeometry.windowHeight
    color: "transparent"
    // Stable transparent allocation must not intercept input in the surrounding desktop.
    mask: Region {
        Region {
            x: Math.floor(inputArea.x)
            y: Math.floor(inputArea.y)
            width: Math.ceil(inputArea.width)
            height: Math.ceil(inputArea.height)
        }
        Region {
            x: Math.floor(contextMenu.x)
            y: Math.floor(contextMenu.y)
            width: contextMenu.visible ? Math.ceil(contextMenu.width) : 0
            height: contextMenu.visible ? Math.ceil(contextMenu.height) : 0
        }
        Region {
            x: Math.floor(folderPopup.x)
            y: Math.floor(folderPopup.y)
            width: folderPopup.visible ? Math.ceil(folderPopup.width) : 0
            height: folderPopup.visible ? Math.ceil(folderPopup.height) : 0
        }
    }
    onVisibleChanged: if (!visible) { contextMenu.dismiss(); folderPopup.dismiss() }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dock"
    WlrLayershell.keyboardFocus: dockFocusPolicy.acceptsKeyboard
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    DockFocusPolicy {
        id: dockFocusPolicy
        surfaceVisible: visibilityController.surfaceVisible
        menuOpen: view.contextMenuOpen
        keyboardNavigationRequested: view.keyboardNavigationRequested
    }

    DockWindowGeometry {
        id: windowGeometry
        baseHeight: root.dockAllocationHeight
        screenHeight: root.screen ? (root.vertical ? root.screen.width : root.screen.height) : 0
        bottomMargin: visibilityController.edgeMode ? 0 : settings.edgeMargin
        edgeHeight: settings.metrics.borderWidth
        surfaceVisible: visibilityController.surfaceVisible
    }
    DockVisibilityController {
        id: visibilityController
        autoHide: panelPolicy.effectiveMode === "autohide"
        dodgeWindows: panelPolicy.effectiveMode === "dodge-windows"
        overlapAvailable: overlap.available
        overlapping: overlap.overlapping
        showingDesktop: overlap.showingDesktop
        configuring: root.configuring
        pointerInside: inputArea.hovered || nativeEdge.pointerInside
        menuOpen: view.contextMenuOpen || folderPopup.visible || folderPopup.preparingToShow || trashConfirmation.visible || trash.confirming || trashState.busy
        keyboardFocused: visibilityController.surfaceVisible && view.keyboardFocused && view.Window.active
        reducedMotion: settings.effectiveReducedMotion
        transitionDuration: settings.slideDuration
        onHiding: slideGeometry.capture(visibilityController.boundedSlideProgress,
            view.measureSlideTravelHeight() + settings.edgeMargin)
        onRevealing: slideGeometry.capture(visibilityController.boundedSlideProgress,
            view.measureSlideTravelHeight() + settings.edgeMargin)
    }
    Native.AutoHideEdge {
        id: nativeEdge
        edge: settings.dockEdge
        retainPointer: true
        enabled: root.visible && visibilityController.edgeMode
        armed: enabled && !visibilityController.surfaceVisible
        width: root.vertical ? Math.max(2, settings.metrics.padding) : root.baseLength
        height: root.vertical ? Math.min(root.baseLength, root.screen ? root.screen.height : root.baseLength)
            : Math.max(2, settings.metrics.padding)
        screenName: root.screen ? root.screen.name : ""
        onRevealRequested: visibilityController.reveal()
    }
    DockInputArea {
        id: inputArea
        objectName: "dock-input-area"
        dockEdge: settings.dockEdge
        edgeLength: root.baseLength
        hostWidth: root.width
        hostHeight: root.height
        contentBounds: Qt.rect(view.x + view.interactionBounds.x,
            view.y + view.interactionBounds.y, view.interactionBounds.width,
            view.interactionBounds.height)
        surfaceVisible: visibilityController.surfaceVisible
        nativeEdgeAvailable: nativeEdge.available
        enabled: root.visible && visibilityController.edgeMode
        onEntered: visibilityController.reveal()
    }
    ShellSettings {
        id: settings
        panelMode: Quickshell.env("PUNCHI_DOCK_MODE") || "overlay"
    }
    DockPanelPolicy {
        id: panelPolicy
        mode: settings.panelMode
        baseHeight: (view.itemCount > 0 ? view.itemSize : 0) + view.padding
            + (root.vertical ? view.padding : view.bottomContentPadding)
        // The compositor also accounts for the selected edge margin. Never reserve
        // the transparent inward allocation used by wave, bounce and balloons.
        bottomClearance: view.waveBottomReserve
    }
    IpcHandler {
        target: "dock"
        function setMode(mode: string): bool {
            if (!panelPolicy.accepts(mode)) return false
            settings.panelMode = mode
            return true
        }
        function revealDock(): bool {
            root.visible = true
            visibilityController.reveal()
            return true
        }
        function focusDock(): bool {
            root.visible = true
            visibilityController.reveal()
            return view.focusItem(Math.max(0, view.currentIndex))
        }
        function openSettings(): bool {
            root.settingsRequested()
            return true
        }
        function snapshot(): string {
            return JSON.stringify({
                mode: panelPolicy.effectiveMode,
                edge: settings.dockEdge,
                vertical: root.vertical,
                windowWidth: root.width,
                screenWidth: root.screen ? root.screen.width : 0,
                dockViewX: view.x,
                dockViewWidth: view.width,
                visible: root.visible,
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
                reducedMotion: settings.effectiveReducedMotion
            })
        }
    }
    ApplicationCatalog { id: availableApps }
    Native.DockItemCatalog {
        id: itemCatalog
        applications: availableApps
        containers: settings.containers
        downloadsTitle: qsTr("Downloads")
        trashTitle: qsTr("Trash")
        trashIconName: trash.iconName
    }
    Native.TrashState { id: trashState }
    TrashService {
        id: trash
        state: trashState
        launcher: contextApplicationAdapter
        onOperationRejected: console.warn("Punchi Dock Quickshell: trash operation rejected")
    }
    Connections {
        target: trashState
        function onOperationFinished(success, error): void {
            if (!success) console.warn("Punchi Dock Quickshell: empty trash failed:", error)
        }
    }
    TrashConfirmationWindow {
        id: trashConfirmation
        service: trash
        questionText: qsTr("Do you want to permanently delete all items in the Trash?")
        warningText: qsTr("This action cannot be undone.")
        reducedMotion: settings.effectiveReducedMotion
    }
    RunningApplications { id: runningApps; catalog: availableApps }
    UpdateNotice { id: updateNotice; settings: root.preferences; catalog: availableApps }
    DockRestingGeometry {
        id: restingGeometry
        dockEdge: settings.dockEdge
        screenX: root.screen ? root.screen.x : 0
        screenY: root.screen ? root.screen.y : 0
        screenWidth: root.screen ? root.screen.width : 0
        screenHeight: root.screen ? root.screen.height : 0
        bodyWidth: root.vertical ? panelPolicy.baseHeight : root.baseLength
        bodyHeight: root.vertical ? Math.min(root.baseLength + view.bottomContentPadding,
            root.screen ? root.screen.height : root.baseLength + view.bottomContentPadding) : panelPolicy.baseHeight
        bottomClearance: view.waveBottomReserve
        edgeMargin: settings.edgeMargin
    }
    WindowOverlap {
        id: overlap
        source: runningApps.visibilityState
        region: restingGeometry.region
    }
    PinnedApplications { id: fixtureModel; catalog: itemCatalog; pinnedIds: settings.pinnedIds
        iconOverrides: settings.iconOverrides }
    RecentApplications {
        id: recentApplications
        settings: settings
        catalog: itemCatalog
        runningDesktopIds: runningApps.desktopIds
    }
    Native.DockApplicationsModel {
        id: dockItems
        pinned: fixtureModel
        catalog: itemCatalog
        recent: recentApplications.selection
        runningDesktopIds: runningApps.available ? runningApps.desktopIds : []
        runningApplications: runningApps.available ? runningApps.applicationEntries : []
    }

    Native.KWinMinimizeEffectController { id: minimizeEffects }

    DesktopApplicationAdapter {
        id: applicationAdapter
        activationItem: view
    }
    DesktopApplicationAdapter {
        id: contextApplicationAdapter
        // The anchor must live in the dock window that received the input. A
        // popup content item has no window until its own surface opens, so
        // anchoring to the context menu refused every folder activation and
        // every location opened from the folder popup while the menu was
        // closed. The window content item is always in the scene.
        activationItem: root.contentItem
    }
    ApplicationLaunchService {
        id: contextLauncher
        entries: dockItems
        adapter: contextApplicationAdapter
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: desktop action rejected:", appId)
        }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: desktop action failed:", desktopId, error)
        }
    }

    ApplicationActivationService {
        id: activation
        entries: dockItems
        launcher: launcher
        newWindowLauncher: newInstanceLauncher
        windowState: runningApps
        onActivationRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: window activation rejected:", appId)
        }
    }
    DockContextPopup {
        id: contextMenu
        settings: settings
        minimizeEffectController: minimizeEffects
        dockEdge: settings.dockEdge
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
        windowActions: runningApps.revision >= 0 ? runningApps.windowActions(contextMenu.appId) : ({})
        virtualDesktops: runningApps.virtualDesktops
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
            if (runningApps.windowActivation.requestWindowAction(contextMenu.appId, action, virtualDesktop) === 0)
                console.warn("Punchi Dock Quickshell: window action request rejected:", action)
        }
        onMediaCommandRequested: function(command) { contextService.controlMedia(command) }
        onFolderSortRequested: function(appId, sortMode) { settings.setContainerSortMode(appId, sortMode) }
        onFolderLayoutRequested: function(appId, layout) { settings.setContainerLayout(appId, layout) }
        onOpenFolderRequested: {
            const entry = settings.container(contextMenu.appId)
            if (entry && entry.path.length > 0) contextApplicationAdapter.openFolderPath(entry.path)
            else contextApplicationAdapter.openDownloads()
        }
        onOpenTrashRequested: trash.open()
        onEmptyTrashRequested: trash.requestEmpty()
        onAutoHideRequested: settings.panelMode = settings.panelMode === "autohide" ? "overlay" : "autohide"
        onMagnificationRequested: settings.magnificationEnabled = !settings.magnificationEnabled
        onDockEdgeRequested: function(edge) { settings.dockEdge = edge }
        onMinimizeEffectRequested: function(effect) {
            if (!minimizeEffects.setEffect(effect)) console.warn("Punchi Dock Quickshell: KWin minimize effect update failed")
        }
    }
    ApplicationContextService {
        id: contextService
        entries: dockItems
        adapter: contextApplicationAdapter
        settings: root.preferences
        onRequestRejected: function(appId) { console.warn("Punchi Dock Quickshell: context request rejected:", appId) }
    }
    ApplicationLaunchService {
        id: launcher
        entries: dockItems
        adapter: applicationAdapter
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: KDE application launch failed:", desktopId, error)
            root.applicationLaunchFinished(desktopId, success, error)
        }
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: application activation rejected:", appId)
        }
    }
    DesktopApplicationAdapter { id: newInstanceAdapter; activationItem: view }
    ApplicationLaunchService {
        id: newInstanceLauncher
        entries: dockItems
        adapter: newInstanceAdapter
        onLaunchRejected: function(appId) { console.warn("Punchi Dock Quickshell: new window rejected:", appId) }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: new window failed:", desktopId, error)
        }
    }
    Connections {
        target: launcher
        function onLaunchDispatched(appId) { recentApplications.recordAccess(appId) }
    }
    Connections {
        target: contextLauncher
        function onLaunchDispatched(appId) { recentApplications.recordAccess(appId) }
    }
    Connections {
        target: newInstanceLauncher
        function onLaunchDispatched(appId) { recentApplications.recordAccess(appId) }
    }
    Connections {
        target: activation
        function onActivationDispatched(appId) { recentApplications.recordAccess(appId) }
    }

    FolderContainerPopup {
        id: folderPopup
        objectName: "downloadsPopup"
        hostWindow: root
        hostBaseHeight: root.dockAllocationHeight
        settings: root.preferences
        opener: contextApplicationAdapter
        clipboardService: clipboard
    }
    ClipboardService { id: clipboard }
    Connections {
        target: settings
        function onPinnedIdsChanged() {
            if (!settings.container(folderPopup.appId)) folderPopup.dismiss()
        }
    }
    DockView {
        id: view
        objectName: "dock-view"
        applicationState: runningApps
        updateState: updateNotice
        contextMenuOpen: contextMenu.visible || contextMenu.preparingToShow || folderPopup.visible || folderPopup.preparingToShow
        onContextMenuRequested: function(sourceItem, appId, title, position) {
            folderPopup.dismiss()
            contextMenu.appId = appId
            contextService.select(appId)
            if (appId.length > 0) contextMenu.openForItem(sourceItem, title)
            else contextMenu.openAt(sourceItem, position)
        }
        dockEdge: settings.dockEdge
        sceneTranslation: Qt.point(slideTransform.x, slideTransform.y)
        availableLength: root.vertical ? root.height : 0
        width: implicitWidth
        height: implicitHeight
        x: settings.dockEdge === "right" ? root.width - width - root.edgeClearance
            : root.vertical ? root.edgeClearance : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 + view.contentCenterOffset
            : root.height - height - root.edgeClearance
        visible: visibilityController.surfaceVisible
        opacity: visibilityController.opacity
        transform: Translate {
            id: slideTransform
            x: visibilityController.edgeMode && root.vertical
                ? (settings.dockEdge === "left" ? -1 : 1)
                    * (1 - visibilityController.boundedSlideProgress) * root.slideDistance : 0
            y: visibilityController.edgeMode && !root.vertical
                ? (1 - visibilityController.boundedSlideProgress) * root.slideDistance : 0
        }
        entries: dockItems
        itemSize: settings.itemSize
        iconSize: settings.iconSize
        itemSpacing: settings.spacing
        padding: settings.padding
        surfaceRadius: settings.surfaceRadius
        bottomContentPadding: settings.bottomContentPadding
        magnificationEnabled: settings.magnificationEnabled
        reducedMotion: settings.effectiveReducedMotion
        maximumIconScale: settings.maximumIconScale
        waveEnterDuration: settings.waveEnterDuration
        waveLeaveDuration: settings.waveLeaveDuration
        clickDuration: settings.clickDuration
        onSettingsRequested: root.settingsRequested()
        onItemActivated: function(appId) {
            contextMenu.dismiss()
            const container = settings.container(appId)
            if (container) folderPopup.toggleForItem(view.itemForId(appId), appId, container)
            else {
                folderPopup.dismiss()
                if (appId === "item:trash") trash.open()
                else activation.activate(appId)
            }
        }
        onItemNewWindowRequested: function(appId) {
            folderPopup.dismiss()
            if (!appId.startsWith("item:")) activation.newWindow(appId)
            contextMenu.dismiss()
        }
        onCloseRequested: if (!root.configuring) root.visible = false
    }
}
