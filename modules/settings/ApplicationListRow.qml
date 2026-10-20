// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

ItemDelegate {
    id: root
    property string iconName
    // Row position supplied by the owning list; -1 outside a list.
    property int rowIndex: -1
    // A selection is the single primary emphasis. Do not add a second
    // background or frame on another row while the pointer moves.
    property bool selectionActive: false
    hoverEnabled: !root.selectionActive
    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            source: root.iconName || "application-x-executable"
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }
        Label {
            text: root.text
            textFormat: Text.PlainText
            font: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
    // Inset hairline between rows; the selected row keeps its single fill.
    Rectangle {
        objectName: "applicationRowSeparator"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Kirigami.Units.mediumSpacing
        anchors.rightMargin: Kirigami.Units.mediumSpacing
        height: 1
        visible: {
            const view = root.ListView.view
            return !root.highlighted && view !== null && view.count > 1
                && root.rowIndex >= 0 && root.rowIndex < view.count - 1
        }
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.16)
        Accessible.ignored: true
    }
}
