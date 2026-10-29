// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One labeled settings row inside a PunchiSettingsCard. The row itself is not
// selectable, so it never competes with the list selection emphasis; only the
// trailing control is focusable and interactive.
ItemDelegate {
    id: root
    objectName: "settingsRow"
    property bool showSeparator: true
    default property alias control: controlRow.data
    readonly property color hairlineColor: Qt.rgba(Kirigami.Theme.textColor.r,
        Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.16)
    hoverEnabled: false
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 2.4,
        implicitContentHeight + topPadding + bottomPadding)
    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Label {
            objectName: "settingsRowLabel"
            Layout.fillWidth: true
            text: root.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: root.font
            color: root.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
        RowLayout {
            id: controlRow
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignVCenter
        }
    }
    background: Item {
        Rectangle {
            objectName: "settingsRowSeparator"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.leftPadding
            height: 1
            visible: root.showSeparator
            color: root.hairlineColor
            Accessible.ignored: true
        }
    }
}
