// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: root
    // A settings category is always current, so the selected fill is the only
    // primary emphasis. Pointer hover must not paint a second background.
    hoverEnabled: false
    readonly property color contentColor: root.checked || root.highlighted
        ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    Accessible.name: root.text
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            objectName: "categoryIcon"
            source: root.icon.name
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            color: root.contentColor
            Accessible.ignored: true
        }
        Label {
            objectName: "categoryLabel"
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font: root.font
            color: root.contentColor
        }
    }
}
