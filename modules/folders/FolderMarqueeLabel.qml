// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// Keeps the folder-entry geometry fixed while allowing a long name to be read.
Item {
    id: root
    objectName: "folderMarqueeLabel"
    property string text: ""
    property font font: Kirigami.Theme.defaultFont
    property color color: Kirigami.Theme.textColor
    property int horizontalAlignment: Text.AlignLeft
    property bool hovered: false
    property bool focused: false
    property bool motionEnabled: true
    readonly property real naturalTextWidth: Math.ceil(textMetrics.advanceWidth)
    // Resting cap of a name. The popup sizes its surface from the same probe
    // (PopupMetrics.maximumRestingNameWidth), so the row never leaves room it
    // cannot paint.
    readonly property real maximumRestingWidth: Math.ceil(restingMetrics.advanceWidth)
    readonly property real viewportWidth: Math.max(0, Math.min(width, maximumRestingWidth))
    readonly property bool overflowing: naturalTextWidth > viewportWidth + 0.5
    readonly property bool revealFullText: overflowing && (hovered || focused)
    readonly property bool fullNameTooltipVisible: overflowing && !motionEnabled && (hovered || focused)
    readonly property real terminalOffset: Math.min(0, viewportWidth - naturalTextWidth)
    readonly property real scrollOffset: movingText.x
    implicitHeight: Math.ceil(fontMetrics.height)
    Accessible.ignored: true

    TextMetrics {
        id: textMetrics
        font: root.font
        text: root.text
    }
    TextMetrics {
        id: restingMetrics
        font: root.font
        text: "MMMMMMMMMM"
    }
    FontMetrics {
        id: fontMetrics
        font: root.font
    }

    Item {
        id: viewport
        x: root.horizontalAlignment === Text.AlignHCenter
            ? (root.width - width) / 2 : 0
        width: root.viewportWidth
        height: root.height
        clip: true

        FolderPopupShadowLabel {
            id: restingText
            objectName: "folderMarqueeRestingText"
            anchors.fill: parent
            text: root.text
            font: root.font
            color: root.color
            textFormat: Text.PlainText
            horizontalAlignment: root.horizontalAlignment
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            opacity: root.revealFullText && root.motionEnabled ? 0 : 1
            Accessible.ignored: true
            Behavior on opacity {
                enabled: root.motionEnabled
                NumberAnimation {
                    duration: Kirigami.Units.veryShortDuration
                    easing.type: Easing.OutQuad
                }
            }
        }

        FolderPopupShadowLabel {
            id: movingText
            objectName: "folderMarqueeMovingText"
            x: root.revealFullText && root.motionEnabled ? root.terminalOffset : 0
            width: root.naturalTextWidth
            height: parent.height
            text: root.text
            font: root.font
            color: root.color
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            maximumLineCount: 1
            opacity: root.revealFullText && root.motionEnabled ? 1 : 0
            visible: opacity > 0.001
            Accessible.ignored: true
            Behavior on x {
                enabled: root.motionEnabled
                SmoothedAnimation {
                    velocity: Math.max(1, Kirigami.Units.gridUnit * 0.65 * 1000
                        / Math.max(1, Kirigami.Units.longDuration))
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on opacity {
                enabled: root.motionEnabled
                NumberAnimation {
                    duration: Kirigami.Units.veryShortDuration
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    ToolTip.visible: root.fullNameTooltipVisible
    ToolTip.text: root.text
}
