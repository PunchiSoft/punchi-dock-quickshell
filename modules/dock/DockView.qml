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
    property int currentIndex: -1
    property bool keyboardNavigationRequested: false
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
    readonly property DockMetrics metrics: DockMetrics {}
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

    implicitWidth: itemCount * itemSize + Math.max(0, itemCount - 1) * itemSpacing
        + leftPadding + rightPadding
    implicitHeight: (itemCount > 0 ? itemSize : 0) + topPadding + bottomPadding
    focusPolicy: Qt.NoFocus
    padding: metrics.padding
    bottomPadding: bottomContentPadding + waveBottomReserve
    topPadding: padding + waveTopReserve
    leftPadding: padding + waveSideReserve
    rightPadding: padding + waveSideReserve

    TooltipStyle { id: tooltipStyle }
    FontMetrics { id: tooltipFont; font: root.font }
    function updatePointerInteraction(): void {
        const position = pointer.point.position
        const bounds = interactionBounds
        const inside = pointer.hovered && position.x >= bounds.x
            && position.x <= bounds.x + bounds.width && position.y >= bounds.y
            && position.y <= bounds.y + bounds.height
        if (inside) lastPointerX = position.x
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

    DockMagnification {
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
            Math.floor((root.lastPointerX - root.leftPadding + root.itemSpacing / 2) / wave.itemPitch))) : -1
        maximumScale: root.boundedIconScale
        enterDuration: root.waveEnterDuration
        leaveDuration: root.waveLeaveDuration
    }

    function focusItem(index) {
        if (index < 0 || index >= tiles.count)
            return false
        root.currentIndex = index
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
            const tile = tiles.itemAt(row) as LauncherTile
            if (tile && tile.activeFocus && tile.visualFocus) { keyboardFocusId = tile.appId; return }
        }
        keyboardFocusId = ""
    }

    function launcherAt(position: point): LauncherTile {
        // Reverse paint order; map through the real scale/translation before
        // testing the same containment mask used by the interactive control.
        for (let i = tiles.count - 1; i >= 0; --i) {
            const tile = tiles.itemAt(i) as LauncherTile
            if (tile && tile.visible && tile.enabled
                    && tile.contains(tile.mapFromItem(root, position.x, position.y)))
                return tile
        }
        return null
    }

    onItemCountChanged: {
        if (root.currentIndex >= root.itemCount)
            root.currentIndex = root.itemCount - 1
        reconcileKeyboardFocus()
    }

    // Observe rendered bounds without feeding them back into logical centers.
    // This bounded scan follows declarative transforms, including exit progress.
    readonly property rect renderedBounds: {
        let left = waveSideReserve
        let right = width - waveSideReserve
        let top = waveTopReserve
        for (let i = 0; i < tiles.count; ++i) {
            const tile = tiles.itemAt(i) as LauncherTile
            if (!tile) continue
            const centerX = tile.x + tile.width / 2 + tile.iconOffsetX
            const halfWidth = tile.width * tile.visualIconScale / 2
            left = Math.min(left, centerX - halfWidth - padding)
            right = Math.max(right, centerX + halfWidth + padding)
            top = Math.min(top, tile.iconTopCenter.y - padding
                - Math.max(0, tile.itemSize - tile.iconSize) * tile.visualIconScale / 2)
        }
        return Qt.rect(left, top, right - left, height - top)
    }
    readonly property rect surfaceBounds: Qt.rect(renderedBounds.x, waveTopReserve,
        renderedBounds.width, height - waveTopReserve - waveBottomReserve)
    readonly property rect interactionBounds: renderedBounds

    // Exclude unused tooltip/bounce headroom, while covering raised launchers.
    // The window captures this extent once per slide, not on each animation frame.
    function measureSlideTravelHeight(): real {
        return Math.ceil(Math.max(1, interactionBounds.height))
    }

    background: AntialiasedSurface {
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
        delegate: LauncherTile {
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
            x: root.leftPadding + index * (root.itemSize + root.itemSpacing)
            y: root.topPadding
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
            magnificationEnabled: root.magnificationEnabled
            reducedMotion: root.reducedMotion || !root.visible || !root.enabled
            clickDuration: tile.appId.startsWith("item:") ? 0 : root.clickDuration
            targetIconScale: wave.scaleAt(tile.x + tile.width / 2, tile.index)
            iconOffsetX: wave.shiftAt(tile.x + tile.width / 2)

            onActivated: {
                root.currentIndex = tile.index
                root.itemActivated(tile.appId)
            }
            onPointerPressed: root.releaseKeyboardNavigation()

            Keys.onLeftPressed: root.focusItem((tile.index + tiles.count - 1) % tiles.count)
            Keys.onRightPressed: root.focusItem((tile.index + 1) % tiles.count)
            Keys.onEscapePressed: root.closeRequested()
        }
    }
}
