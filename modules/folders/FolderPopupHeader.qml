// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// Title row of a folder container: the way back to the parent folder, the title
// and the close control. The arc has no card to carry this chrome, so the
// container only shows it for the flat presentations.
Item {
    id: root
    property string title: ""
    property bool canGoBack: false
    signal backRequested()
    signal closeRequested()
    implicitHeight: Math.max(back.implicitHeight, closeButton.implicitHeight)
    function focusFirst(): void {
        if (back.visible) back.forceActiveFocus(Qt.PopupFocusReason)
        else closeButton.forceActiveFocus(Qt.PopupFocusReason)
    }
    ToolButton {
        id: back
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        objectName: "folderBack"
        text: qsTr("Back"); icon.name: "go-previous"
        display: AbstractButton.IconOnly
        visible: root.canGoBack
        enabled: visible
        Accessible.name: text
        HoverHandler {
            objectName: "folderBackCursor"
            enabled: back.enabled
            cursorShape: Qt.PointingHandCursor
        }
        onClicked: root.backRequested()
    }
    FolderPopupShadowLabel {
        anchors.centerIn: parent
        objectName: "folderPopupTitle"
        width: Math.max(0, root.width - (back.visible ? back.width : 0)
            - closeButton.width - Kirigami.Units.largeSpacing * 2)
        text: root.title
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
        font.weight: Font.DemiBold
        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
    }
    ToolButton {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        objectName: "folderClose"
        width: Kirigami.Units.gridUnit * 1.5
        height: width
        padding: 0
        Accessible.name: qsTr("Close")
        background: Rectangle {
            anchors.centerIn: parent
            width: Kirigami.Units.gridUnit * 0.75
            height: width
            radius: width / 2
            color: Kirigami.Theme.negativeTextColor
        }
        HoverHandler {
            objectName: "folderCloseCursor"
            cursorShape: Qt.PointingHandCursor
        }
        onClicked: root.closeRequested()
    }
}
