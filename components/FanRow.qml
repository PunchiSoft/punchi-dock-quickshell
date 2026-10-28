// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami


// One row of the folder fan: a glyph on the arc and the pill that carries its
// name. The view owns the arc and hands each row its lean, its curve position
// and the share of the opening it has reached; the row only paints, reports
// intent and keeps the dock's pointer and keyboard profile.
ItemDelegate {
    id: root

    property string label: ""
    property string iconSource: ""
    // The closing row opens the folder instead of a file, so its glyph and its
    // accessible action differ from an entry.
    property bool locationAction: false
    property real iconX: 0
    property int iconSize: 42
    property real rowLean: 0
    // Travel from the anchor row to the row's own place, applied while opening.
    property real curveSlide: 0
    property real travelSlide: 0
    property real progress: 1
    // Ceiling the view reserves for one name; the pill hugs the text below it.
    property real labelWidthCap: 0
    property int labelHeight: 0
    property bool showLabels: true
    property bool iconsOnRight: true
    property bool motionEnabled: true
    // The fan owns which signal paints the band; see FanView.
    property bool pointerEmphasis: true
    property int contentPadding: Kirigami.Units.smallSpacing
    property int labelSpacing: Kirigami.Units.smallSpacing
    property int itemIndex: -1
    property int itemCount: 0

    signal activated()
    signal closeRequested()
    signal stepRequested(int step)
    signal focusReceived()

    readonly property font labelFont: Qt.font({
        family: Kirigami.Theme.defaultFont.family,
        pointSize: Kirigami.Theme.defaultFont.pointSize,
        weight: Font.DemiBold
    })
    readonly property int labelHorizontalPadding: Kirigami.Units.smallSpacing * 2
    readonly property int labelRoundingMargin: 1
    readonly property real safeProgress: Number.isFinite(Number(progress))
        ? Math.max(0, Math.min(1, Number(progress))) : 1
    readonly property real naturalLabelWidth: Math.ceil(labelMetrics.advanceWidth)
        + root.labelHorizontalPadding * 2 + root.labelRoundingMargin
    readonly property real availableLabelWidth: root.iconsOnRight
        ? Math.max(0, root.iconX - root.labelSpacing - root.contentPadding)
        : Math.max(0, root.width - root.contentPadding
            - (root.iconX + root.iconSize + root.labelSpacing))
    readonly property real pillWidth: root.showLabels && root.label.length > 0
        ? Math.min(root.labelWidthCap, root.naturalLabelWidth,
            root.availableLabelWidth) : 0

    // The row paints no fill of its own beyond the icon highlight: a full-row
    // focus or hover band would compete with the arc and with the selection the
    // pill already expresses.
    background: Item {}
    padding: 0
    spacing: 0
    hoverEnabled: true
    // The arc is the third presentation of the same entries, so it repeats the
    // pointing hand of the flat listings while the row can act.
    HoverHandler {
        objectName: "folderFanCursor"
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus
    opacity: root.motionEnabled ? 0.78 + 0.22 * root.safeProgress : 1
    transform: Translate {
        x: root.curveSlide * (1 - root.safeProgress)
        y: root.travelSlide * (1 - root.safeProgress)
    }

    Accessible.name: root.label
    Accessible.description: root.locationAction
        ? qsTr("Open this folder in the file manager")
        : root.itemIndex >= 0 && root.itemCount > 0
            ? qsTr("Item %1 of %2").arg(root.itemIndex + 1).arg(root.itemCount) : ""
    Accessible.onPressAction: root.activated()

    onClicked: root.activated()
    onActiveFocusChanged: if (activeFocus) root.focusReceived()
    Keys.onUpPressed: function(event) {
        root.stepRequested(-1)
        event.accepted = true
    }
    Keys.onDownPressed: function(event) {
        root.stepRequested(1)
        event.accepted = true
    }
    Keys.onEscapePressed: function(event) {
        root.closeRequested()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        root.activated()
        event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
        root.activated()
        event.accepted = true
    }
    Keys.onSpacePressed: function(event) {
        root.activated()
        event.accepted = true
    }

    contentItem: Item {
        id: rowContent
        scale: fanHighlight.visualScale

        // The row turns as one rigid group about the centre of its glyph, so the
        // glyph stays on the arc and its pill travels with it.
        transform: Rotation {
            origin.x: root.iconX + root.iconSize / 2
            origin.y: rowContent.height / 2
            angle: root.rowLean
        }

        PopupRowHighlight {
            id: fanHighlight
            objectName: "folderFanHighlight"
            x: root.iconX - Kirigami.Units.smallSpacing
            y: Math.round(Kirigami.Units.smallSpacing / 2)
            width: root.iconSize + Kirigami.Units.smallSpacing * 2
            height: Math.max(0, rowContent.height - Kirigami.Units.smallSpacing)
            radius: Kirigami.Units.cornerRadius
            hovered: root.hovered && root.pointerEmphasis
            focused: root.visualFocus && !root.pointerEmphasis
            pressed: root.pressed
            motionEnabled: root.motionEnabled
        }

        Rectangle {
            id: pill
            objectName: "folderFanPill"
            x: root.iconsOnRight
                ? root.iconX - root.labelSpacing - root.pillWidth
                : root.iconX + root.iconSize + root.labelSpacing
            width: root.pillWidth
            height: root.labelHeight
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pillWidth > 0 && root.labelHeight > 0
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.88)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            antialiasing: true
            Accessible.ignored: true

            EntryMarqueeLabel {
                objectName: "folderFanLabel"
                anchors.fill: parent
                anchors.leftMargin: root.labelHorizontalPadding
                anchors.rightMargin: root.labelHorizontalPadding
                text: root.label
                hovered: root.hovered && root.pointerEmphasis
                focused: root.visualFocus && !root.pointerEmphasis
                motionEnabled: root.motionEnabled
                color: Kirigami.Theme.textColor
                horizontalAlignment: root.iconsOnRight
                    ? Text.AlignRight : Text.AlignLeft
                font: root.labelFont
            }
        }

        Kirigami.Icon {
            objectName: "folderFanIcon"
            x: root.iconX
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            source: root.iconSource.length > 0 ? root.iconSource
                : "application-x-executable"
            color: "transparent"
            Accessible.ignored: true
        }
    }

    TextMetrics {
        id: labelMetrics
        font: root.labelFont
        text: root.label
    }
}
