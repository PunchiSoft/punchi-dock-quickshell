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

PanelWindow {
    id: root
    property alias preferences: settings
    readonly property alias applicationCatalog: itemCatalog
    property bool configuring: false
    DockConfigurationController { hostWindow: root; active: root.configuring }
    signal settingsRequested()
    signal applicationLaunchFinished(string desktopId, bool success, string error)

    // Coexist with Plasma and respect its reserved screen space.
    anchors.bottom: true
    exclusiveZone: panelPolicy.exclusiveZone
    exclusionMode: visibilityController.edgeMode ? ExclusionMode.Ignore : ExclusionMode.Normal
    margins.bottom: visibilityController.edgeMode ? 0 : settings.edgeMargin
    implicitWidth: visibilityController.surfaceVisible ? view.implicitWidth
        : view.itemCount * settings.itemSize + Math.max(0, view.itemCount - 1) * settings.spacing
            + settings.padding * 2
    readonly property real dockAllocationHeight: view.implicitHeight
        + (visibilityController.edgeMode ? settings.edgeMargin : 0)
    readonly property real slideDistance: slideGeometry.distance
    DockSlideGeometry { id: slideGeometry }
    implicitHeight: windowGeometry.windowHeight
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
    }
    onVisibleChanged: if (!visible) contextMenu.dismiss()
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
        screenHeight: root.screen ? root.screen.height : 0
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
        menuOpen: view.contextMenuOpen || trashConfirmation.visible || trash.confirming || trashState.busy
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
        retainPointer: true
        enabled: root.visible && visibilityController.edgeMode
        armed: enabled && !visibilityController.surfaceVisible
        width: view.itemCount * settings.itemSize
            + Math.max(0, view.itemCount - 1) * settings.spacing + settings.padding * 2
        height: Math.max(2, settings.metrics.padding)
        screenName: root.screen ? root.screen.name : ""
        onRevealRequested: visibilityController.reveal()
    }
    DockInputArea {
        id: inputArea
        objectName: "dock-input-area"
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
        baseHeight: (view.itemCount > 0 ? view.itemSize : 0) + view.padding + view.bottomContentPadding
        // The compositor also accounts for margins.bottom. Never reserve the
        // transparent top area used by wave, bounce, and balloons.
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
                visible: root.visible,
                layer: root.WlrLayershell.layer,
                exclusiveZone: root.exclusiveZone,
                baseHeight: panelPolicy.baseHeight,
                windowHeight: root.height,
                surfaceVisible: visibilityController.surfaceVisible,
                opacity: visibilityController.opacity,
                slideProgress: visibilityController.boundedSlideProgress,
                slideOffset: slideTransform.y,
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
        trashTitle: qsTr("Trash")
        trashIconName: trash.iconName
    }
    Native.TrashState { id: trashState }
    TrashService {
        id: trash
        state: trashState
        launcher: contextApplicationAdapter
        onOperationRejected: console.warn("Punchi Shell: trash operation rejected")
    }
    Connections {
        target: trashState
        function onOperationFinished(success, error): void {
            if (!success) console.warn("Punchi Shell: empty trash failed:", error)
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
    DockRestingGeometry {
        id: restingGeometry
        screenX: root.screen ? root.screen.x : 0
        screenY: root.screen ? root.screen.y : 0
        screenWidth: root.screen ? root.screen.width : 0
        screenHeight: root.screen ? root.screen.height : 0
        bodyWidth: view.itemCount * settings.itemSize
            + Math.max(0, view.itemCount - 1) * settings.spacing + settings.padding * 2
        bodyHeight: panelPolicy.baseHeight
        bottomClearance: view.waveBottomReserve
        edgeMargin: settings.edgeMargin
    }
    WindowOverlap {
        id: overlap
        source: runningApps.visibilityState
        region: restingGeometry.region
    }
    PinnedApplications { id: fixtureModel; catalog: itemCatalog; pinnedIds: settings.pinnedIds }
    Native.DockApplicationsModel {
        id: dockItems
        pinned: fixtureModel
        catalog: itemCatalog
        runningDesktopIds: runningApps.available ? runningApps.desktopIds : []
    }

    DesktopApplicationAdapter {
        id: applicationAdapter
        activationItem: view
    }
    DesktopApplicationAdapter {
        id: contextApplicationAdapter
        activationItem: contextMenu.mainItem
    }
    ApplicationLaunchService {
        id: contextLauncher
        entries: dockItems
        adapter: contextApplicationAdapter
        onLaunchRejected: function(appId) {
            console.warn("Punchi Shell: desktop action rejected:", appId)
        }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Shell: desktop action failed:", desktopId, error)
        }
    }

    ApplicationActivationService {
        id: activation
        entries: dockItems
        launcher: launcher
        newWindowLauncher: newInstanceLauncher
        windowState: runningApps
        onActivationRejected: function(appId) {
            console.warn("Punchi Shell: window activation rejected:", appId)
        }
    }
    DockContextPopup {
        id: contextMenu
        hostWindow: root
        hostBaseHeight: root.dockAllocationHeight
        actions: contextService.actions
        recentDocuments: contextService.recentDocuments
        places: contextService.places
        media: contextService.media
        usesPlaces: contextService.usesPlaces
        canLaunchNewWindow: contextService.canLaunchNewWindow
        pinned: contextService.pinned
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
        onUnpinRequested: contextService.unpin()
        onMediaCommandRequested: function(command) { contextService.controlMedia(command) }
        onOpenTrashRequested: trash.open()
        onEmptyTrashRequested: trash.requestEmpty()
    }
    ApplicationContextService {
        id: contextService
        entries: dockItems
        adapter: contextApplicationAdapter
        settings: root.preferences
        onRequestRejected: function(appId) { console.warn("Punchi Shell: context request rejected:", appId) }
    }
    ApplicationLaunchService {
        id: launcher
        entries: dockItems
        adapter: applicationAdapter
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Shell: KDE application launch failed:", desktopId, error)
            root.applicationLaunchFinished(desktopId, success, error)
        }
        onLaunchRejected: function(appId) {
            console.warn("Punchi Shell: application activation rejected:", appId)
        }
    }
    DesktopApplicationAdapter { id: newInstanceAdapter; activationItem: view }
    ApplicationLaunchService {
        id: newInstanceLauncher
        entries: dockItems
        adapter: newInstanceAdapter
        onLaunchRejected: function(appId) { console.warn("Punchi Shell: new window rejected:", appId) }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Shell: new window failed:", desktopId, error)
        }
    }

    DockView {
        id: view
        applicationState: runningApps
        contextMenuOpen: contextMenu.visible || contextMenu.preparingToShow
        onContextMenuRequested: function(sourceItem, appId, title, position) {
            contextMenu.appId = appId
            contextService.select(appId)
            if (appId.length > 0) contextMenu.openForItem(sourceItem, title)
            else contextMenu.openAt(sourceItem, position)
        }
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
        anchors.bottomMargin: visibilityController.edgeMode && visibilityController.surfaceVisible
            ? settings.edgeMargin : 0
        visible: visibilityController.surfaceVisible
        opacity: visibilityController.opacity
        transform: Translate {
            id: slideTransform
            y: visibilityController.edgeMode
                ? (1 - visibilityController.boundedSlideProgress)
                    * root.slideDistance : 0
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
        waveSharedScaleLimit: settings.waveSharedScaleLimit
        waveEnterDuration: settings.waveEnterDuration
        waveLeaveDuration: settings.waveLeaveDuration
        clickDuration: settings.clickDuration
        onSettingsRequested: root.settingsRequested()
        onItemActivated: function(appId) {
            if (appId === "item:trash") trash.open()
            else activation.activate(appId)
            contextMenu.dismiss()
        }
        onItemNewWindowRequested: function(appId) {
            if (!appId.startsWith("item:")) activation.newWindow(appId)
            contextMenu.dismiss()
        }
        onCloseRequested: if (!root.configuring) root.visible = false
    }
}
