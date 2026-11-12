// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import "../../components"

// One application cell. The surface decides which modality owns the single
// emphasis band, so this cell never paints hover and keyboard selection at the
// same time; the pointer still gets its hand cursor and its hover animation.
Item {
    id: root

    objectName: "menuTile"
    required property string title
    required property string iconName
    property bool selected: false
    // Published by the surface: true while the pointer moved last.
    property bool pointerEmphasis: true
    property bool motionEnabled: true
    property bool showLabel: true
    property string hoverAnimation: "pulse"
    property int iconSize: Kirigami.Units.iconSizes.huge

    readonly property bool hovered: pointer.containsMouse && root.pointerEmphasis
    readonly property real labelHeight: root.showLabel
        ? Math.ceil(Kirigami.Theme.defaultFont.pixelSize * 1.6) : 0
    // Zero means the cell is not laid out yet. A NaN or zero must never reach a
    // raster request, and a one-pixel request makes Qt's SVG renderer rasterise a
    // degenerate filter region that it reports as an oversized buffer.
    readonly property real availableWidth: {
        const available = Number(highlight.width) - Kirigami.Units.gridUnit
        return Number.isFinite(available) && available > 1 ? available : 0
    }
    readonly property real contentWidth: Math.max(1, root.availableWidth)
    readonly property real iconPixels: {
        const requested = Number(root.iconSize)
        // A parent that has not laid out its row yet may pass 1 as a sentinel.
        // Never turn that into a raster request: Qt reports a 1x1 SVG draw as an
        // oversized buffer.
        const bounded = Number.isFinite(requested) && requested > 1
            ? requested : Kirigami.Units.iconSizes.huge
        return root.availableWidth > 0 ? Math.min(bounded, root.availableWidth) : bounded
    }

    signal activated()
    // The pointer entered this cell; the surface turns it into the current row so
    // exactly one band is painted.
    signal pointerEntered()

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: qsTr("Open %1").arg(root.title)
    Accessible.focused: root.selected && !root.pointerEmphasis
    Accessible.onPressAction: root.activated()

    PunchiMenuHighlight {
        id: highlight
        anchors.fill: parent
        hovered: root.hovered && root.pointerEmphasis
        selected: root.selected && !root.pointerEmphasis
        pressed: pointer.pressed
        motionEnabled: root.motionEnabled
        animationMode: root.hoverAnimation

        Column {
            anchors.centerIn: parent
            width: root.contentWidth
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.iconPixels
                height: root.iconPixels
                source: root.iconName.length > 0
                    ? root.iconName : "application-x-executable"
                Accessible.ignored: true
            }
            PunchiEntryMarqueeLabel {
                visible: root.showLabel
                width: root.contentWidth
                height: root.labelHeight
                text: root.title
                font: Kirigami.Theme.defaultFont
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                hovered: root.hovered && root.pointerEmphasis
                focused: root.selected && !root.pointerEmphasis
                motionEnabled: root.motionEnabled
                maximumRestingWidth: root.contentWidth
                // The menu paints many labels at once; skip the per-cell effect.
                shadowEnabled: false
            }
        }
    }

    MouseArea {
        id: pointer
        objectName: "menuTilePointer"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.pointerEntered()
        onClicked: root.activated()
    }
}
