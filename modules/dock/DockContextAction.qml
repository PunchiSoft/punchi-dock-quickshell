// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: root
    property bool submenu: false
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
    FontMetrics { id: metrics; font: root.font }
    contentItem: RowLayout {
        spacing: root.spacing
        Kirigami.Icon {
            source: root.icon.name
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
        }
        Label {
            text: root.text
            font: root.font
            color: root.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Kirigami.Icon {
            visible: root.submenu
            source: "go-next"
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
        }
    }
    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: root.hovered || root.activeFocus || root.down
            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.2) : "transparent"
    }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
