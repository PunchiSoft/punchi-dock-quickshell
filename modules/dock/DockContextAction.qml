// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

ItemDelegate {
    id: root
    property bool submenu: false
    property bool marked: false
    focusPolicy: Qt.StrongFocus
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.smallSpacing
    horizontalPadding: Kirigami.Units.smallSpacing * 2
    spacing: Kirigami.Units.smallSpacing * 2
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
    implicitHeight: Math.max(metrics.height, icon.height) + topPadding + bottomPadding
    implicitWidth: metrics.advanceWidth(text) + icon.width + spacing + leftPadding + rightPadding
        + (submenu ? icon.width + spacing : 0)
    palette.windowText: Kirigami.Theme.textColor
    readonly property bool emphasized: root.enabled && (root.hovered || root.down)
    FontMetrics { id: metrics; font: root.font }
    contentItem: RowLayout {
        spacing: root.spacing
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
                : root.down ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
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
    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        opacity: (root.emphasized || root.visualFocus) ? 1 : 0
        color: root.emphasized ? (root.down ? Kirigami.Theme.focusColor
            : Qt.alpha(Kirigami.Theme.focusColor, 0.3)) : "transparent"
        border.color: Kirigami.Theme.focusColor
        border.width: (root.emphasized || root.visualFocus) ? 1 : 0
    }
    Keys.onReturnPressed: if (root.enabled) root.clicked()
    Keys.onEnterPressed: if (root.enabled) root.clicked()
}
