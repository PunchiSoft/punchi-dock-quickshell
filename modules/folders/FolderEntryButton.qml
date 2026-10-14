// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

ItemDelegate {
    id: root
    property string entryName: ""
    property string entryIcon: ""
    property string description: ""
    property bool grid: true
    property bool detailed: false
    property bool locationAction: false
    property bool motionEnabled: true
    property real gridIconSize: Kirigami.Units.gridUnit * 3
    text: locationAction ? qsTr("Open in File Manager") : entryName
    focusPolicy: Qt.StrongFocus
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.smallSpacing
    Accessible.name: text
    Accessible.description: detailed ? description : ""
    background: Rectangle {
        radius: root.grid ? Kirigami.Units.smallSpacing : 0
        color: root.grid && root.locationAction ? "transparent"
            : (root.hovered || root.visualFocus || root.highlighted)
                ? Qt.alpha(Kirigami.Theme.highlightColor, root.grid ? 0.14 : 0.22)
                : "transparent"
        border.width: root.grid && root.visualFocus ? 1 : 0
        border.color: Kirigami.Theme.highlightColor
    }
    contentItem: GridLayout {
        id: entryContent
        objectName: "folderEntryContent"
        visible: true
        columns: root.grid ? 1 : 2
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.largeSpacing
        Item {
            objectName: "folderEntryIconArea"
            Layout.preferredWidth: root.grid ? root.gridIconSize : Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignHCenter
            Accessible.ignored: true
            Rectangle {
                objectName: "folderGridOpenLocationControl"
                anchors.fill: parent
                visible: root.grid && root.locationAction
                radius: width / 2
                color: root.hovered || root.visualFocus
                    ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
                    : Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.22)
            }
            Kirigami.Icon {
                objectName: "folderEntryIcon"
                Native.IconThemeRefresh.enabled: true
                anchors.centerIn: parent
                width: root.locationAction ? Kirigami.Units.iconSizes.medium : parent.width
                height: width
                source: root.locationAction ? "folder-open" : root.entryIcon
                color: root.locationAction ? Kirigami.Theme.textColor : "transparent"
                Accessible.ignored: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            FolderMarqueeLabel {
                id: entryNameLabel
                Layout.fillWidth: true
                objectName: "folderEntryNameLabel"
                text: root.grid && root.locationAction ? qsTr("Open") : root.text
                horizontalAlignment: root.grid ? Text.AlignHCenter : Text.AlignLeft
                font: root.grid ? Qt.font({
                    family: Kirigami.Theme.defaultFont.family,
                    pointSize: Kirigami.Theme.defaultFont.pointSize + 2,
                    weight: Font.DemiBold
                }) : root.font
                hovered: root.hovered
                focused: root.visualFocus
                motionEnabled: root.motionEnabled
            }
            Label {
                Layout.fillWidth: true
                visible: root.detailed
                text: root.description
                textFormat: Text.PlainText
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
        }
    }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
