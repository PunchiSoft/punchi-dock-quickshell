// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"

// Shared popup policy of the top panel: one rounded card with an upward tail
// anchored to the trigger, clamped to the window it lives in, closable with
// Escape or an outside click, and restoring the trigger's focus on close.
Popup {
    id: root
    property Item anchorItem: null
    // "right" pins the popup to the window's right margin, like a control
    // centre opening toward the screen edge; "left" pins it to its trigger.
    property string alignment: "center"
    property real preferredWidth: Kirigami.Units.gridUnit * 13
    property real inset: Kirigami.Units.largeSpacing
    property real tailHeight: Kirigami.Units.largeSpacing
    // The panel window owns the screen geometry; clamp against it, never the
    // bar, so a tall card can use the space under the bar.
    readonly property real screenMargin: Kirigami.Units.smallSpacing
    readonly property real windowWidth: root.parent ? root.parent.width : root.preferredWidth
    readonly property real windowHeight: root.parent ? root.parent.height : 0
    // The trigger is laid out after this popup is created. Reading its x/width
    // (times zero) keeps the binding dependent on the layout result; mapToItem
    // alone is a function call QML cannot track, which left the card at the
    // screen edge before the first layout.
    readonly property real anchorLeftX: root.anchorItem && root.parent
        ? root.anchorItem.mapToItem(root.parent, 0, 0).x + root.anchorItem.x * 0
        : root.screenMargin
    readonly property real anchorRightX: root.anchorItem && root.parent
        ? root.anchorItem.mapToItem(root.parent, root.anchorItem.width, 0).x
            + root.anchorItem.width * 0 + root.anchorItem.x * 0
        : root.screenMargin
    readonly property real anchorCenterX: (root.anchorLeftX + root.anchorRightX) / 2
    readonly property real anchorBottomY: root.anchorItem && root.parent
        ? root.anchorItem.mapToItem(root.parent, 0, root.anchorItem.height).y
            + root.anchorItem.y * 0 + root.anchorItem.height * 0
        : 0
    readonly property real desiredX: root.alignment === "right"
        ? root.windowWidth - root.width - root.screenMargin
        : root.alignment === "left" ? root.anchorLeftX
        : root.anchorCenterX - root.width / 2
    // Space a content card may use inside this popup. A card that can overflow
    // reads it and scrolls instead of growing past the screen edge.
    readonly property real maximumContentHeight: Math.max(Kirigami.Units.gridUnit * 4,
        root.windowHeight - root.anchorBottomY - root.screenMargin * 2
            - root.tailHeight - root.inset * 2)
    readonly property real pointerX: Math.max(Kirigami.Units.gridUnit,
        Math.min(root.width - Kirigami.Units.gridUnit, root.anchorCenterX - root.x))
    default property alias popupContent: contentColumn.data
    objectName: "topBarPopup"
    modal: false
    dim: false
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: null
    width: Math.round(Math.min(root.preferredWidth,
        Math.max(0, root.windowWidth - root.screenMargin * 2)))
    height: Math.round(Math.min(contentItem.implicitHeight,
        Math.max(0, root.windowHeight - root.screenMargin * 2)))
    x: Math.round(Math.max(root.screenMargin,
        Math.min(root.windowWidth - root.width - root.screenMargin, root.desiredX)))
    y: Math.round(Math.max(root.screenMargin,
        Math.min(root.windowHeight - root.height - root.screenMargin,
            root.anchorBottomY + Kirigami.Units.smallSpacing)))
    onOpened: Qt.callLater(root.focusFirst)
    onClosed: if (root.anchorItem && root.anchorItem.visible && root.anchorItem.enabled)
        root.anchorItem.forceActiveFocus(Qt.PopupFocusReason)
    function focusFirst(): void {
        const items = contentColumn.children
        for (let index = 0; index < items.length; ++index) {
            const item = items[index]
            if (item && typeof item.focusFirst === "function") {
                item.focusFirst()
                return
            }
        }
    }
    contentItem: Item {
        id: surface
        implicitWidth: root.width
        implicitHeight: root.tailHeight + contentColumn.implicitHeight + root.inset * 2
        PunchiBalloonSurface {
            objectName: "topBarPopupSurface"
            anchors.fill: parent
            tailEdge: "top"
            tailHeight: root.tailHeight
            pointerX: root.pointerX
            cornerRadius: Kirigami.Units.cornerRadius * 2
        }
        ColumnLayout {
            id: contentColumn
            objectName: "topBarPopupContent"
            x: root.inset
            y: root.tailHeight + root.inset
            width: surface.width - root.inset * 2
            spacing: Kirigami.Units.smallSpacing
        }
    }
}
