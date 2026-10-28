// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"
import "../../config"

// Menu a folder row opens with the secondary button or the Menu key. It stays
// inside the popup surface, so the container keeps its focus and the outer popup
// does not treat the choice as a click outside, and it reuses the shared row,
// radius and focus ring of the popup family.
Item {
    id: root
    objectName: "folderEntryMenu"
    property Item anchorItem: null
    property string entryName: ""
    property url entryUrl: ""
    property string entryPath: ""
    property bool directory: false
    property bool motionEnabled: true
    property bool pointerEmphasis: true

    // Exactly one row paints an emphasis band. Real pointer motion hands it to
    // the pointer; a keyboard focus move hands it back to the keyboard, so a
    // focused row and another hovered row never light up together.
    property point lastPointerPosition: Qt.point(-1, -1)
    HoverHandler {
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }
    // Window.activeFocusItem is typed as a bare item, so read the focus reason
    // through an untyped helper the linter can follow.
    function focusReasonOf(item): int {
        return item ? item["focusReason"] : Qt.OtherFocusReason
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const item = root.Window.activeFocusItem
            if (!item) return
            let ancestor = item
            while (ancestor && ancestor !== root) ancestor = ancestor.parent
            if (!ancestor) return
            const reason = root.focusReasonOf(item)
            root.pointerEmphasis = reason !== Qt.TabFocusReason
                && reason !== Qt.BacktabFocusReason && reason !== Qt.ShortcutFocusReason
        }
    }
    property bool copyAvailable: true
    readonly property PopupMetrics metrics: PopupMetrics {}
    signal openLocationRequested()
    signal copyPathRequested()
    anchors.fill: parent
    visible: false
    z: 10
    Accessible.name: root.entryName
    function open(anchor: Item): void {
        if (!anchor) return
        root.anchorItem = anchor
        card.x = Kirigami.Units.smallSpacing
        root.visible = true
        Qt.callLater(function() {
            if (!root.visible || !anchor) return
            const point = anchor.mapToItem(root, 0, anchor.height)
            card.x = Math.max(Kirigami.Units.smallSpacing,
                Math.min(root.width - card.width - Kirigami.Units.smallSpacing, point.x))
            card.y = Math.max(Kirigami.Units.smallSpacing,
                Math.min(root.height - card.height - Kirigami.Units.smallSpacing,
                    point.y + Kirigami.Units.smallSpacing))
            openLocationRow.forceActiveFocus(Qt.MouseFocusReason)
        })
    }
    function close(): void {
        const anchor = root.anchorItem
        root.visible = false
        root.anchorItem = null
        if (anchor && anchor.visible) anchor.forceActiveFocus(Qt.PopupFocusReason)
    }
    Keys.onEscapePressed: root.close()
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }
    Item {
        id: card
        width: Math.min(root.width - Kirigami.Units.smallSpacing * 2,
            column.implicitWidth + Kirigami.Units.smallSpacing * 2)
        height: column.implicitHeight + Kirigami.Units.smallSpacing * 2
        Rectangle {
            anchors.fill: parent
            radius: root.metrics.rowRadius
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.98)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
        }
        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 0
            PopupActionRow {
                id: openLocationRow
                objectName: "folderEntryOpenLocation"
                pointerEmphasis: root.pointerEmphasis
                Layout.fillWidth: true
                motionEnabled: root.motionEnabled
                text: qsTr("Open in File Manager")
                icon.name: "folder-open"
                onClicked: {
                    root.openLocationRequested()
                    root.close()
                }
            }
            PopupActionRow {
                pointerEmphasis: root.pointerEmphasis
                objectName: "folderEntryCopyPath"
                Layout.fillWidth: true
                motionEnabled: root.motionEnabled
                enabled: root.copyAvailable && root.entryPath.length > 0
                text: qsTr("Copy Path")
                icon.name: "edit-copy"
                onClicked: {
                    root.copyPathRequested()
                    root.close()
                }
            }
        }
    }
}
