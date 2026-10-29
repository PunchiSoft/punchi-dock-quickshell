// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Search entry of the menu header. It owns its frame, its clear affordance and
// its accessible name, so the header only positions it.
Controls.TextField {
    id: root

    objectName: "menuSearchField"
    property bool motionEnabled: true

    readonly property bool frameActive: root.activeFocus || root.hovered
    readonly property color frameColor: root.frameActive
        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.24)
        : Qt.alpha(Kirigami.Theme.textColor, 0.10)

    signal cleared()

    placeholderText: qsTr("Search applications…")
    Accessible.name: qsTr("Search applications")
    selectByMouse: true
    leftPadding: Kirigami.Units.gridUnit * 2
    rightPadding: Kirigami.Units.gridUnit * 2.4
    verticalAlignment: TextInput.AlignVCenter
    font: Kirigami.Theme.defaultFont
    color: Kirigami.Theme.textColor
    placeholderTextColor: Kirigami.Theme.disabledTextColor
    background: Rectangle {
        radius: height / 2
        color: root.frameColor
        border.width: root.activeFocus ? 1 : 0
        border.color: Kirigami.Theme.highlightColor
        Behavior on color {
            enabled: root.motionEnabled
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }
    Kirigami.Icon {
        anchors.left: parent.left
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: Kirigami.Units.iconSizes.small
        roundToIconSize: true
        source: "system-search-symbolic"
        color: Kirigami.Theme.textColor
        Accessible.ignored: true
    }
    Controls.ToolButton {
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.gridUnit * 1.6
        height: width
        visible: root.text.length > 0
        icon.name: "edit-clear-symbolic"
        text: qsTr("Clear search")
        Accessible.name: qsTr("Clear search")
        onClicked: root.cleared()
    }
}
