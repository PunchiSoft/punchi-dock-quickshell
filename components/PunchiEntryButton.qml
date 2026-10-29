// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../config"

ItemDelegate {
    id: root
    property string entryName: ""
    property string entryIcon: ""
    property string description: ""
    property bool grid: true
    property bool detailed: false
    property bool locationAction: false
    property bool directory: false
    // The container enters its directories, so a folder row says so with a
    // trailing glyph and the label keeps its room.
    property bool browsable: false
    property bool motionEnabled: true
    // The container shares one metrics object with every row, so the row only
    // carries its own states.
    property PunchiPopupMetrics metrics: PunchiPopupMetrics {}
    // Which emphasis the pointer owns. The container turns it off while the
    // keyboard moves, so a row never shows the pointer band and the selection
    // band at the same time.
    property bool pointerEmphasis: true
    readonly property bool actionRow: root.locationAction
    signal contextRequested(var anchor)
    // The reference calls the row "Open" in every presentation; the file
    // manager only survives in the accessible description.
    text: root.actionRow ? qsTr("Open") : root.entryName
    focusPolicy: Qt.StrongFocus
    font: Kirigami.Theme.defaultFont
    padding: Kirigami.Units.smallSpacing
    horizontalPadding: Kirigami.Units.smallSpacing * 2
    Accessible.name: root.actionRow ? qsTr("Open") : root.entryName
    Accessible.description: root.actionRow ? qsTr("Open this folder in the file manager")
        : root.detailed ? root.description : ""
    // Every listing row is a pointer target, so the popup keeps one hand cursor
    // for its rows and its entries while the row can act.
    HoverHandler {
        objectName: "folderEntryCursor"
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    background: PunchiPopupRowHighlight {
        id: rowHighlight
        anchors.margins: root.metrics.rowInset
        radius: root.metrics.rowRadius
        borderThickness: root.metrics.rowBorderWidth
        hoverColor: root.metrics.rowHoverColor
        hoverBorderColor: root.metrics.rowHoverBorderColor
        selectedColor: root.metrics.rowSelectedColor
        // The pointer band belongs to the pointer; the solid band marks the row
        // the keyboard is on.
        hovered: root.hovered && root.pointerEmphasis
        selected: root.highlighted && !root.pointerEmphasis
        pressed: root.down
        motionEnabled: root.motionEnabled
    }
    contentItem: GridLayout {
        id: entryContent
        scale: rowHighlight.visualScale
        objectName: "folderEntryContent"
        visible: true
        columns: root.grid ? 1 : (chevron.visible ? 3 : 2)
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.largeSpacing
        Item {
            objectName: "folderEntryIconArea"
            Layout.preferredWidth: root.grid ? root.metrics.gridIconSize : root.metrics.listIconSize
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignHCenter
            Accessible.ignored: true
            Kirigami.Icon {
                objectName: "folderEntryIcon"
                Native.IconThemeRefresh.enabled: true
                anchors.centerIn: parent
                width: parent.width
                height: width
                source: root.entryIcon
                // Entry glyphs keep the colours the icon theme gives them,
                // including the coloured folder the open action shows.
                color: "transparent"
                Accessible.ignored: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PunchiEntryMarqueeLabel {
                id: entryNameLabel
                Layout.fillWidth: true
                objectName: "folderEntryNameLabel"
                text: root.text
                color: rowHighlight.marked ? root.metrics.rowSelectedTextColor
                    : Kirigami.Theme.textColor
                horizontalAlignment: root.grid ? Text.AlignHCenter : Text.AlignLeft
                font: root.grid ? Qt.font({
                    family: Kirigami.Theme.defaultFont.family,
                    pointSize: Kirigami.Theme.defaultFont.pointSize,
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
        Kirigami.Icon {
            id: chevron
            objectName: "folderEntryChevron"
            Native.IconThemeRefresh.enabled: true
            visible: root.browsable && !root.grid && !root.actionRow
            source: "go-next-symbolic"
            color: Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Accessible.ignored: true
        }
    }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onMenuPressed: function(event) {
        root.contextRequested(root)
        event.accepted = true
    }
}
