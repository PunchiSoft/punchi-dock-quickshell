// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: root
    // A settings category is always current, so the selected fill is the only
    // primary emphasis. Pointer hover must not paint a second background; the
    // pointing-hand cursor is the only pointer feedback.
    hoverEnabled: false
    HoverHandler {
        objectName: "categoryCursor"
        cursorShape: Qt.PointingHandCursor
    }
    readonly property color contentColor: root.checked || root.highlighted
        ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    Accessible.name: root.text
    contentItem: RowLayout {
        spacing: Kirigami.Units.mediumSpacing
        Kirigami.Icon {
            objectName: "categoryIcon"
            source: root.icon.name
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            color: root.contentColor
            Accessible.ignored: true
        }
        Label {
            objectName: "categoryLabel"
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font: root.font
            color: root.contentColor
        }
    }
}
