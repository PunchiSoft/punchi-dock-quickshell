// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../config"

// One row of a popup menu: glyph, label and an optional trailing mark. Every
// popup of the dock uses it, so the folder containers, the context menu and its
// sections share one hover, one radius and one focus ring.
ItemDelegate {
    id: root
    property bool submenu: false
    // The surface owns which signal paints the band; see PunchiDockContextContent.
    property bool pointerEmphasis: true
    property bool marked: false
    property bool motionEnabled: true
    // A row whose label can be longer than its width reveals the full text with
    // PunchiEntryMarqueeLabel, the same carousel the menu labels use. Other
    // popup rows keep the resting elide.
    property bool marquee: false
    readonly property PunchiPopupMetrics metrics: PunchiPopupMetrics {}
    focusPolicy: Qt.StrongFocus
    // The marquee label never exposes its glyphs, so the row carries the name.
    Accessible.name: root.text
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.smallSpacing
    horizontalPadding: Kirigami.Units.smallSpacing * 2
    spacing: Kirigami.Units.smallSpacing * 2
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
    implicitHeight: Math.max(labelMetrics.height, icon.height) + topPadding + bottomPadding
    implicitWidth: labelMetrics.advanceWidth(text) + icon.width + spacing + leftPadding + rightPadding
        + (submenu || marked ? icon.width + spacing : 0)
    palette.windowText: Kirigami.Theme.textColor
    FontMetrics { id: labelMetrics; font: root.font }
    // Qt 6 has no Item.cursorShape, so the hand of the popup family belongs to a
    // passive handler. It follows the row's enablement, because a row that cannot
    // act keeps the arrow and still reports itself as hovered.
    HoverHandler {
        objectName: "popupRowCursor"
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    contentItem: RowLayout {
        spacing: root.spacing
        scale: rowHighlight.visualScale
        // Keep a high-resolution source and scale the scene transform, as the
        // dock tile does. A 16 px raster of an icon with a mask or a group
        // opacity asks Qt SVG for a degenerate buffer while the source changes;
        // the 64 px source avoids that warning and stays sharp on high-DPI
        // screens.
        Item {
            objectName: "popupRowIconArea"
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
            Kirigami.Icon {
                objectName: "popupRowIcon"
                Native.IconThemeRefresh.enabled: true
                source: root.icon.name
                selected: root.down
                anchors.centerIn: parent
                width: Math.max(64, root.icon.width)
                height: width
                scale: root.icon.width / width
                roundToIconSize: false
                smooth: true
                Accessible.ignored: true
            }
        }
        PunchiEntryMarqueeLabel {
            objectName: "popupRowMarqueeLabel"
            visible: root.marquee
            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: !root.enabled ? Kirigami.Theme.disabledTextColor
                : rowHighlight.marked ? Kirigami.Theme.highlightedTextColor
                : Kirigami.Theme.textColor
            maximumRestingWidth: width
            hovered: root.hovered
            focused: root.visualFocus
            motionEnabled: root.motionEnabled
            shadowEnabled: false
        }
        Label {
            objectName: "popupRowLabel"
            visible: !root.marquee
            text: root.text
            font: root.font
            color: !root.enabled ? Kirigami.Theme.disabledTextColor
                : rowHighlight.marked ? Kirigami.Theme.highlightedTextColor
                : Kirigami.Theme.textColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            visible: root.submenu || root.marked
            source: root.marked ? "dialog-ok" : "go-next"
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
        }
    }
    background: PunchiPopupRowHighlight {
        id: rowHighlight
        anchors.margins: root.metrics.rowInset
        radius: root.metrics.rowRadius
        borderThickness: root.metrics.rowBorderWidth
        hoverColor: root.metrics.rowHoverColor
        hoverBorderColor: root.metrics.rowHoverBorderColor
        // A menu has no persistent selection: the pointer and the keyboard paint
        // the same band, as the native menu does.
        hovered: root.enabled && root.hovered && root.pointerEmphasis
        focused: root.enabled && root.visualFocus && !root.pointerEmphasis
        pressed: root.enabled && root.down
        motionEnabled: root.motionEnabled
    }
    Keys.onReturnPressed: if (root.enabled) root.clicked()
    Keys.onEnterPressed: if (root.enabled) root.clicked()
}
