// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: root
    property Item sourceItem: null
    property string itemName: ""
    property rect capturedGeometry: Qt.rect(0, 0, 1, 1)
    function captureItem(item: var, title: string): bool {
        if (!item || !item.Window.contentItem) return false
        sourceItem = item
        itemName = title
        if (item.iconTopCenter !== undefined && item.iconSize !== undefined) {
            const top = item.parent.mapToItem(item.Window.contentItem, item.iconTopCenter.x, item.iconTopCenter.y)
            const size = item.iconSize * item.visualIconScale
            capturedGeometry = Qt.rect(top.x - size / 2, top.y, size, size)
        } else {
            capturedGeometry = item.mapToItem(item.Window.contentItem, Qt.rect(0, 0, item.width, item.height))
        }
        return true
    }
    function capturePoint(item: Item, position: point): bool {
        if (!item || !item.Window.contentItem) return false
        sourceItem = item
        itemName = ""
        const point = item.mapToItem(item.Window.contentItem, position.x, position.y)
        capturedGeometry = Qt.rect(point.x, point.y, 1, 1)
        return true
    }
}
