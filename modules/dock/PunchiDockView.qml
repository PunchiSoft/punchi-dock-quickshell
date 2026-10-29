// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "../../components"
import "../../config"

Control {
    id: root

    required property var entries
    property var applicationState: null
    property var updateState: null
    property string dockEdge: "bottom"
    readonly property bool vertical: dockEdge === "left" || dockEdge === "right"
    property int currentIndex: -1
    property bool keyboardNavigationRequested: false
    property point sceneTranslation: Qt.point(0, 0)
    property real availableLength: 0
    property real scrollOffset: 0
    property bool scrollPositionChangedByUser: false
    readonly property real maximumScroll: vertical ? Math.max(0, naturalHeight - height) : 0
    readonly property real centeredScrollOffset: vertical
        ? Math.max(0, Math.min(maximumScroll, topPadding + itemLength / 2 - height / 2)) : 0
    // Center the icon run itself, excluding unequal decorative reserves.
    readonly property real contentCenterOffset: vertical && maximumScroll === 0
        ? (bottomPadding - topPadding) / 2 : 0
    onMaximumScrollChanged: scrollOffset = scrollPositionChangedByUser
        ? Math.max(0, Math.min(maximumScroll, scrollOffset)) : centeredScrollOffset
    onHeightChanged: if (vertical && !scrollPositionChangedByUser) scrollOffset = centeredScrollOffset
    onDockEdgeChanged: {
        scrollPositionChangedByUser = false
        scrollOffset = centeredScrollOffset
        pointerEngaged = false
        Qt.callLater(root.updatePointerInteraction)
    }
    clip: vertical && maximumScroll > 0
    WheelHandler {
        enabled: root.vertical && root.maximumScroll > 0 && !root.contextMenuOpen
        target: null
        onWheel: function(event) {
            const delta = event.pixelDelta.y || event.angleDelta.y / 120 * (root.itemSize + root.itemSpacing)
            root.scrollPositionChangedByUser = true
            root.scrollOffset = Math.max(0, Math.min(root.maximumScroll, root.scrollOffset - delta))
            Qt.callLater(root.updatePointerInteraction)
            event.accepted = true
        }
    }
    property bool restoreRemovedFocus: false
    property string keyboardFocusId: ""
    property int keyboardFocusIndex: -1
    Connections {
        target: root.entries
        function onCountChanged() { root.reconcileKeyboardFocus() }
    }
    readonly property bool hostActive: root.Window.active
    onHostActiveChanged: if (!hostActive) {
        keyboardFocusId = ""
        keyboardNavigationRequested = false
    }
    onVisibleChanged: if (!visible) keyboardNavigationRequested = false
    readonly property PunchiDockMetrics metrics: PunchiDockMetrics {}
    property int itemSize: metrics.itemSize
    property int iconSize: metrics.iconSize
    property int itemSpacing: metrics.spacing
    property real surfaceRadius: metrics.surfaceRadius
    property int bottomContentPadding: metrics.bottomContentPadding
    property bool magnificationEnabled: true
    property bool reducedMotion: false
    property real maximumIconScale: 2.0
    property int clickDuration: Kirigami.Units.longDuration
    readonly property real clickTopReserve: Math.ceil(iconSize * 0.45)
    property int waveEnterDuration: 110
    property int waveLeaveDuration: 85
    readonly property real boundedZoomScale: Number.isFinite(maximumIconScale)
        ? Math.max(1, Math.min(3, maximumIconScale)) : 1
    // The normal theme size retains the percentage contract. Smaller bases can
    // reach the same theme-derived ceiling; 100% always means no enlargement.
    readonly property real maximumIconSize: iconSize
        + (Math.max(iconSize, metrics.maximumMagnifiedIconSize) - iconSize) * (boundedZoomScale - 1) / 2
    readonly property real boundedIconScale: Number.isFinite(iconSize) && iconSize > 0
        ? maximumIconSize / iconSize : 1
    readonly property real tooltipReserve: Math.ceil(tooltipFont.height
        + tooltipStyle.padding * 2 + tooltipStyle.tailHeight + tooltipStyle.gap)
    readonly property real waveTopReserve: Math.ceil((itemSize + iconSize) * 0.5 * (boundedIconScale - 1))
        + tooltipReserve + clickTopReserve
    readonly property real waveSideReserve: Math.ceil(wave.maximumShift
        + itemSize * (boundedIconScale - 1) / 2)
    readonly property real waveBottomReserve: Math.ceil(Math.max(0,
        (itemSize - iconSize) * 0.5 * (boundedIconScale - 1)))
    property real lastPointerX: 0
    property bool pointerEngaged: false
    readonly property bool pointerHovered: pointerEngaged
    readonly property int itemCount: tiles.count
    signal itemActivated(string appId)
    signal itemNewWindowRequested(string appId)
    signal closeRequested()
    signal settingsRequested()
    property bool contextMenuOpen: false
    signal contextMenuRequested(Item sourceItem, string appId, string title, point position)
    readonly property bool keyboardFocused: currentIndex >= 0 && currentIndex < tiles.count
        && tiles.itemAt(currentIndex).activeFocus
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onPressedChanged: if (pressed) root.releaseKeyboardNavigation()
        onTapped: function(eventPoint) {
            const tile = root.launcherAt(eventPoint.position)
            if (tile) root.itemNewWindowRequested(tile.appId)
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onPressedChanged: if (pressed) root.releaseKeyboardNavigation()
        onTapped: function(eventPoint) {
            const tile = root.launcherAt(eventPoint.position)
            root.contextMenuRequested(tile || root, tile ? tile.appId : "",
                tile ? tile.title : "", eventPoint.position)
        }
    }

    readonly property real itemLength: itemCount * itemSize + Math.max(0, itemCount - 1) * itemSpacing
    implicitWidth: (vertical ? (itemCount > 0 ? itemSize : 0) : itemLength) + leftPadding + rightPadding
    readonly property real naturalHeight: (vertical ? itemLength : (itemCount > 0 ? itemSize : 0)) + topPadding + bottomPadding
    implicitHeight: vertical && availableLength > 0 ? Math.min(naturalHeight, availableLength) : naturalHeight
    focusPolicy: Qt.NoFocus
    padding: metrics.padding
    bottomPadding: vertical ? padding + waveSideReserve + bottomContentPadding : bottomContentPadding + waveBottomReserve
    topPadding: padding + (vertical ? waveSideReserve : waveTopReserve)
    leftPadding: padding + (vertical ? (dockEdge === "right" ? waveTopReserve : waveBottomReserve) : waveSideReserve)
    rightPadding: padding + (vertical ? (dockEdge === "left" ? waveTopReserve : waveBottomReserve) : waveSideReserve)

    PunchiTooltipStyle { id: tooltipStyle }
    FontMetrics { id: tooltipFont; font: root.font }
    function updatePointerInteraction(): void {
        const position = pointer.point.position
        const bounds = interactionBounds
        const inside = pointer.hovered && position.x >= bounds.x
            && position.x <= bounds.x + bounds.width && position.y >= bounds.y
            && position.y <= bounds.y + bounds.height
        if (inside) lastPointerX = vertical ? position.y + scrollOffset : position.x
        pointerEngaged = inside
    }

    HoverHandler {
        id: pointer
        enabled: root.enabled && root.visible
        blocking: false
        onPointChanged: root.updatePointerInteraction()
        onHoveredChanged: root.updatePointerInteraction()
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    PunchiDockMagnification {
        id: wave
        active: (root.pointerHovered || root.contextMenuOpen) && root.visible && root.enabled
        enabled: root.magnificationEnabled
        reducedMotion: root.reducedMotion
        pointerX: root.lastPointerX
        itemPitch: root.itemSize + root.itemSpacing
        iconSize: root.iconSize
        // Magnify the natural icon cell, not extra layout padding in a wider slot.
        itemSize: Math.min(root.itemSize, root.iconSize + root.metrics.itemSize - root.metrics.iconSize)
        activeIndex: root.itemCount > 0 ? Math.max(0, Math.min(root.itemCount - 1,
            Math.floor((root.lastPointerX - (root.vertical ? root.topPadding : root.leftPadding) + root.itemSpacing / 2) / wave.itemPitch))) : -1
        maximumScale: root.boundedIconScale
        enterDuration: root.waveEnterDuration
        leaveDuration: root.waveLeaveDuration
    }

    function keyboardActivation(item): bool {
        return !!item && item.activeFocus && item.visualFocus
    }
    function itemForId(appId: string): Item {
        for (let index = 0; index < tiles.count; ++index) {
            const item = tiles.itemAt(index) as PunchiDockTile
            if (item && item.appId === appId) return item
        }
        return null
    }
    function focusItem(index) {
        if (index < 0 || index >= tiles.count)
            return false
        root.currentIndex = index
        if (vertical && maximumScroll > 0) {
            scrollPositionChangedByUser = true
            const start = topPadding + index * (itemSize + itemSpacing)
            const end = start + itemSize + bottomContentPadding
            if (start - padding < scrollOffset) scrollOffset = Math.max(0, start - padding)
            else if (end + padding > scrollOffset + height)
                scrollOffset = Math.min(maximumScroll, end + padding - height)
        }
        root.keyboardNavigationRequested = true
        tiles.itemAt(index).forceActiveFocus(Qt.TabFocusReason)
        return true
    }
    function releaseKeyboardNavigation(): void {
        keyboardNavigationRequested = false
        keyboardFocusId = ""
    }
    function restoreKeyboardFocus(): void {
        if (!restoreRemovedFocus) return
        restoreRemovedFocus = false
        if (!focusItem(Math.min(keyboardFocusIndex, itemCount - 1))) keyboardFocusId = ""
    }
    function reconcileKeyboardFocus(): void {
        if (!keyboardFocusId) return
        for (let row = 0; row < entries.count; ++row)
            if (entries.get(row).appId === keyboardFocusId) return
        restoreRemovedFocus = true
        currentIndex = Math.min(keyboardFocusIndex, entries.count - 1)
        Qt.callLater(root.restoreKeyboardFocus)
    }
    function clearKeyboardFocusIdentity(): void {
        if (restoreRemovedFocus) return
        for (let row = 0; row < tiles.count; ++row) {
            const tile = tiles.itemAt(row) as PunchiDockTile
            if (tile && tile.activeFocus && tile.visualFocus) { keyboardFocusId = tile.appId; return }
        }
        keyboardFocusId = ""
    }

    function launcherAt(position: point): PunchiDockTile {
        // Reverse paint order; map through the real scale/translation before
        // testing the same containment mask used by the interactive control.
        for (let i = tiles.count - 1; i >= 0; --i) {
            const tile = tiles.itemAt(i) as PunchiDockTile
            if (tile && tile.visible && tile.enabled
                    && tile.contains(tile.mapFromItem(root, position.x, position.y)))
                return tile
        }
        return null
    }

    onItemCountChanged: {
        if (vertical) {
            scrollPositionChangedByUser = false
            Qt.callLater(function() { root.scrollOffset = root.centeredScrollOffset })
        }
        if (root.currentIndex >= root.itemCount)
            root.currentIndex = root.itemCount - 1
        reconcileKeyboardFocus()
    }

    // Observe rendered bounds without feeding them back into logical centers.
    // This bounded scan follows declarative transforms, including exit progress.
    readonly property rect renderedBounds: {
        let left = vertical ? leftPadding - padding : waveSideReserve
        let right = vertical ? leftPadding + itemSize + padding : width - waveSideReserve
        let top = vertical ? topPadding - padding : waveTopReserve
        let bottom = vertical ? height - waveSideReserve : height
        for (let i = 0; i < tiles.count; ++i) {
            const tile = tiles.itemAt(i) as PunchiDockTile
            if (!tile) continue
            const centerX = tile.x + tile.width / 2 + tile.iconOffsetX
            const halfWidth = tile.width * tile.visualIconScale / 2
            left = Math.min(left, centerX - halfWidth - padding)
            right = Math.max(right, centerX + halfWidth + padding)
            top = Math.min(top, tile.iconTopCenter.y - padding
                - Math.max(0, tile.itemSize - tile.iconSize) * tile.visualIconScale / 2)
            if (vertical) bottom = Math.max(bottom, tile.iconTopCenter.y
                + tile.iconSize * tile.visualIconScale + padding + bottomContentPadding)
        }
        if (vertical && maximumScroll > 0) {
            top = Math.max(0, top)
            bottom = Math.min(height, bottom)
        }
        return Qt.rect(left, top, right - left, bottom - top)
    }
    readonly property rect surfaceBounds: vertical
        ? Qt.rect(leftPadding - padding, renderedBounds.y, itemSize + padding * 2, renderedBounds.height)
        : Qt.rect(renderedBounds.x, waveTopReserve, renderedBounds.width,
                  height - waveTopReserve - waveBottomReserve)
    readonly property rect interactionBounds: renderedBounds

    // Exclude unused tooltip/bounce headroom, while covering raised launchers.
    // The window captures this extent once per slide, not on each animation frame.
    function measureSlideTravelHeight(): real {
        return Math.ceil(Math.max(1, vertical ? interactionBounds.width : interactionBounds.height))
    }

    background: PunchiAntialiasedSurface {
        objectName: "dock-surface"
        x: root.surfaceBounds.x
        y: root.surfaceBounds.y
        width: root.surfaceBounds.width
        height: root.surfaceBounds.height
        Rectangle {
            anchors.fill: parent
            radius: root.surfaceRadius
            color: root.palette.window
            border.width: root.metrics.borderWidth
            border.color: root.palette.mid
        }
    }

    contentItem: Item {}

    // Stable logical centers; visual controls are parented to the full surface
    // so their raised/scaled hit targets remain reachable outside base cells.
    Repeater {
        id: tiles
        model: root.entries
        delegate: PunchiDockTile {
            id: tile
            tooltipsEnabled: !root.contextMenuOpen
            required property int index
            onIndexChanged: if (activeFocus) root.currentIndex = index
            onActiveFocusChanged: {
                if (activeFocus) root.currentIndex = index
                if (activeFocus && visualFocus) {
                    root.keyboardFocusId = appId; root.keyboardFocusIndex = index
                }
                else Qt.callLater(root.clearKeyboardFocusIdentity)
            }
            onVisualFocusChanged: {
                if (activeFocus && visualFocus) {
                    root.keyboardFocusId = appId; root.keyboardFocusIndex = index
                }
                else Qt.callLater(root.clearKeyboardFocusIdentity)
            }
            onFocusReasonChanged: {
                if (activeFocus && (focusReason === Qt.TabFocusReason
                    || focusReason === Qt.BacktabFocusReason || focusReason === Qt.ShortcutFocusReason))
                    root.keyboardNavigationRequested = true
            }
            required appId
            parent: root
            x: root.leftPadding + (root.vertical ? 0 : index * (root.itemSize + root.itemSpacing))
            y: root.topPadding + (root.vertical ? index * (root.itemSize + root.itemSpacing) - root.scrollOffset : 0)
            readonly property real axisCenter: root.vertical
                ? root.topPadding + index * (root.itemSize + root.itemSpacing) + height / 2
                : x + width / 2
            width: root.itemSize
            height: root.itemSize
            objectName: "launcher-" + appId
            itemSize: root.itemSize
            iconSize: root.iconSize
            maximumIconScale: root.boundedIconScale
            running: {
                if (!root.applicationState) return false
                root.applicationState.revision
                return root.applicationState.isRunning(tile.appId)
            }
            updateCount: {
                if (!root.updateState) return 0
                root.updateState.revision
                return root.updateState.badgeCount(tile.appId)
            }
            updateSecurityCount: {
                if (!root.updateState) return 0
                root.updateState.revision
                return root.updateState.badgeSecurityCount(tile.appId)
            }
            updateApplying: {
                if (!root.updateState) return false
                root.updateState.revision
                return root.updateState.badgeApplying(tile.appId)
            }
            magnificationEnabled: root.magnificationEnabled
            reducedMotion: root.reducedMotion || !root.visible || !root.enabled
            clickDuration: tile.appId.startsWith("item:") ? 0 : root.clickDuration
            dockEdge: root.dockEdge
            targetIconScale: wave.scaleAt(tile.axisCenter, tile.index)
            axisOffset: wave.shiftAt(tile.axisCenter)

            onActivated: {
                root.currentIndex = tile.index
                root.itemActivated(tile.appId)
            }
            onPointerPressed: root.releaseKeyboardNavigation()

            Keys.onLeftPressed: if (!root.vertical) root.focusItem((tile.index + tiles.count - 1) % tiles.count)
            Keys.onRightPressed: if (!root.vertical) root.focusItem((tile.index + 1) % tiles.count)
            Keys.onUpPressed: if (root.vertical) root.focusItem((tile.index + tiles.count - 1) % tiles.count)
            Keys.onDownPressed: if (root.vertical) root.focusItem((tile.index + 1) % tiles.count)
            Keys.onEscapePressed: root.closeRequested()
        }
    }
}
