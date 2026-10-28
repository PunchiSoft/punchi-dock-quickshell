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
    // The surface owns which signal paints the band; see DockContextContent.
    property bool pointerEmphasis: true
    property bool marked: false
    property bool motionEnabled: true
    readonly property PopupMetrics metrics: PopupMetrics {}
    focusPolicy: Qt.StrongFocus
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
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            source: root.icon.name
            selected: root.down
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
        }
        Label {
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
    background: PopupRowHighlight {
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
