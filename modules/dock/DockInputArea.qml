// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick

// Extend effective content bounds toward the edge, excluding unused allocation.
Item {
    id: root
    property string dockEdge: "bottom"
    property real edgeLength: 0
    property real hostWidth: 0
    property real hostHeight: 0
    property real surfaceTop: 0
    property rect contentBounds: Qt.rect(0, surfaceTop, hostWidth, hostHeight - surfaceTop)
    property bool surfaceVisible: true
    property bool nativeEdgeAvailable: false
    readonly property bool hovered: containment.inside
    QtObject { id: containment; property bool inside: false }
    signal entered()

    readonly property real contentLeft: Math.max(0, Math.min(hostWidth, contentBounds.x))
    readonly property real contentRight: Math.max(contentLeft, Math.min(hostWidth, contentBounds.x + contentBounds.width))
    readonly property real contentTop: Math.max(0, Math.min(hostHeight, contentBounds.y))
    readonly property real contentBottom: Math.max(contentTop, Math.min(hostHeight, contentBounds.y + contentBounds.height))
    x: surfaceVisible && dockEdge !== "left" ? contentLeft : 0
    y: surfaceVisible ? contentTop : dockEdge !== "bottom" && edgeLength > 0
        ? Math.max(0, (hostHeight - edgeLength) / 2) : 0
    width: !surfaceVisible && nativeEdgeAvailable ? 0
        : !surfaceVisible || dockEdge === "right" ? Math.max(0, hostWidth - x)
        : dockEdge === "left" ? contentRight : Math.max(0, contentRight - x)
    height: !surfaceVisible && dockEdge !== "bottom" && edgeLength > 0 ? Math.min(hostHeight, edgeLength)
        : !surfaceVisible || dockEdge === "bottom" ? Math.max(0, hostHeight - y)
        : Math.max(0, contentBottom - y)
    Accessible.ignored: true
    onHoveredChanged: if (hovered) entered()
    function updateContainment(): void {
        containment.inside = enabled && visible && pointer.hovered
            && pointer.point.position.x >= x && pointer.point.position.x < x + width
            && pointer.point.position.y >= y && pointer.point.position.y < y + height
    }
    // Coalesce actual pointer/geometry events after layout; reveal can resize
    // the host, so never mutate it from a geometry-dependent hover binding.
    onXChanged: Qt.callLater(root.updateContainment)
    onYChanged: Qt.callLater(root.updateContainment)
    onWidthChanged: Qt.callLater(root.updateContainment)
    onHeightChanged: Qt.callLater(root.updateContainment)
    onEnabledChanged: Qt.callLater(root.updateContainment)
    onVisibleChanged: Qt.callLater(root.updateContainment)
    Component.onDestruction: pointer.destroy()

    HoverHandler {
        id: pointer
        // Observe the common ancestor; an overlay sibling can block icon hover.
        parent: root.parent
        enabled: root.enabled
        blocking: false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onPointChanged: Qt.callLater(root.updateContainment)
        onHoveredChanged: Qt.callLater(root.updateContainment)
    }
}
