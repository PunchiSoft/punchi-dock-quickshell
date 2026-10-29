// SPDX-License-Identifier: GPL-3.0-or-later
// One popup anchor per surface: it captures the launcher the popup was opened from
// and follows the rendered icon while the magnification moves it. The dock contexts,
// the folder container and the recent container share it.
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: root
    property Item sourceItem: null
    property bool followRenderedIcon: false
    property string itemName: ""
    property rect capturedGeometry: Qt.rect(0, 0, 1, 1)
    readonly property rect anchorGeometry: followRenderedIcon && sourceItem
        ? renderedItemGeometry(sourceItem) : capturedGeometry
    function renderedItemGeometry(item: var): rect {
        if (!item || !item.Window.contentItem) return capturedGeometry
        if (item.iconTopCenter === undefined || item.iconSize === undefined) return capturedGeometry
        // mapToItem does not declare dependencies on the dock's translation.
        // The source contract is a launcher directly parented to DockView.
        item.parent.x; item.parent.y; item.parent.width; item.parent.height; item.parent.scale
        // DockView publishes its transform as a notifying point property.
        // Reading Item.transform itself would depend on a non-bindable list.
        if (item.parent.sceneTranslation !== undefined) item.parent.sceneTranslation
        const top = item.parent.mapToItem(item.Window.contentItem, item.iconTopCenter.x, item.iconTopCenter.y)
        const size = item.iconSize * item.visualIconScale
        return Qt.rect(top.x - size / 2, top.y, size, size)
    }
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
