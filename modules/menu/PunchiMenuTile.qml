// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// One application cell. The surface decides which modality owns the single
// emphasis band, so this cell never paints hover and keyboard selection at the
// same time; the pointer still gets its hand cursor and its hover animation.
Item {
    id: root

    required property string title
    required property string iconName
    property bool selected: false
    // Published by the surface: true while the pointer moved last.
    property bool pointerEmphasis: true
    property bool motionEnabled: true
    property bool showLabel: true
    property string hoverAnimation: "pulse"
    property int iconSize: Kirigami.Units.iconSizes.huge

    readonly property bool hovered: pointer.containsMouse && root.pointerEmphasis

    signal activated()
    // The pointer entered this cell; the surface turns it into the current row so
    // exactly one band is painted.
    signal pointerEntered()

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: qsTr("Open %1").arg(root.title)
    Accessible.focused: root.selected && !root.pointerEmphasis
    Accessible.onPressAction: root.activated()

    PunchiMenuHighlight {
        id: highlight
        anchors.fill: parent
        hovered: root.hovered && root.pointerEmphasis
        selected: root.selected && !root.pointerEmphasis
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
                height: root.showLabel
                    ? Math.ceil(Kirigami.Theme.defaultFont.pixelSize * 2.4) : 0
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
        objectName: "menuTilePointer"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.pointerEntered()
        onClicked: root.activated()
    }
}
