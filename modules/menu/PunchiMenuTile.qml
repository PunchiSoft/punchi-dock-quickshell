// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// One application cell. Hover, press and selection are separate inputs so the
// pointer never looks like the keyboard cursor, and the hover animation is the
// same four-mode behaviour the original menu offered.
Item {
    id: root

    required property string title
    required property string iconName
    property bool selected: false
    property bool motionEnabled: true
    property bool showLabel: true
    property string hoverAnimation: "pulse"
    property int iconSize: Kirigami.Units.iconSizes.huge

    readonly property bool hovered: pointer.containsMouse
    readonly property real labelHeight: root.showLabel
        ? Math.ceil(Kirigami.Theme.defaultFont.pixelSize * 2.4) : 0

    signal activated()

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: qsTr("Open %1").arg(root.title)
    Accessible.onPressAction: root.activated()

    PunchiMenuHighlight {
        id: highlight
        anchors.fill: parent
        hovered: root.hovered
        selected: root.selected
        pressed: pointer.pressed
        motionEnabled: root.motionEnabled
        animationMode: root.hoverAnimation

        Column {
            anchors.centerIn: parent
            width: Math.max(1, parent.width - Kirigami.Units.gridUnit)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(root.iconSize, Math.max(1, parent.width))
                height: width
                source: root.iconName.length > 0
                    ? root.iconName : "application-x-executable"
                Accessible.ignored: true
            }
            Controls.Label {
                visible: root.showLabel
                width: parent.width
                height: root.labelHeight
                text: root.title
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font: Kirigami.Theme.defaultFont
                color: Kirigami.Theme.textColor
                Accessible.ignored: true
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}
