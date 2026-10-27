// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../config"

ToolButton {
    id: root

    required property string title
    required property string iconName
    property string appId: ""
    property string dockEdge: "bottom"
    readonly property bool vertical: dockEdge === "left" || dockEdge === "right"
    readonly property real inwardDirection: dockEdge === "left" ? 1 : -1
    property real axisOffset: 0
    property bool running: false
    property int updateCount: 0
    property int updateSecurityCount: 0
    property bool updateApplying: false
    property bool tooltipsEnabled: true
    readonly property DockMetrics metrics: DockMetrics {}
    property int itemSize: metrics.itemSize
    property int iconSize: metrics.iconSize
    property real maximumIconScale: 2
    readonly property int highQualityIconSize: {
        const targetSize = Math.ceil(iconSize * Math.max(1, maximumIconScale))
        if (targetSize <= iconSize) return iconSize
        if (targetSize <= 64 && iconSize < 64) return 64
        if (targetSize <= 96) return 96
        if (targetSize <= 128) return 128
        if (targetSize <= 256) return 256
        return Math.min(512, targetSize)
    }
    property real targetIconScale: 1
    property bool reducedMotion: false
    property int clickDuration: Kirigami.Units.longDuration
    readonly property bool feedbackRunning: feedback.running
    readonly property real clickOffsetY: feedback.verticalOffset
    signal activated()
    signal pointerPressed()
    onPressed: if (focusReason === Qt.MouseFocusReason) root.pointerPressed()
    onFocusReasonChanged: if (pressed && focusReason === Qt.MouseFocusReason) root.pointerPressed()
    property bool magnificationEnabled: true
    readonly property real visualIconScale: magnificationEnabled ? targetIconScale : 1
    property real iconOffsetX: vertical
        ? inwardDirection * (iconSize * 0.5 * (visualIconScale - 1) - clickOffsetY) : axisOffset
    readonly property real iconOffsetY: vertical ? axisOffset
        : -iconSize * 0.5 * (visualIconScale - 1) + clickOffsetY
    // Parent coordinates, shared by unscaled surfaces attached to the icon.
    readonly property point iconTopCenter: Qt.point(
        root.x + root.width / 2 + root.iconOffsetX,
        root.y + root.height / 2 + root.iconOffsetY - root.iconSize * root.visualIconScale / 2)

    readonly property real highlightInset: Kirigami.Units.smallSpacing
    containmentMask: QtObject {
        function contains(position: point): bool {
            const halfWidth = root.width / 2 - root.highlightInset
            const halfHeight = root.height / 2 - root.highlightInset
            return Math.abs(position.x - root.width / 2) <= halfWidth
                && Math.abs(position.y - root.height / 2) <= halfHeight
        }
    }

    scale: visualIconScale
    transform: Translate {
        x: root.iconOffsetX
        y: root.iconOffsetY
    }

    implicitWidth: itemSize
    implicitHeight: itemSize
    text: title
    display: AbstractButton.IconOnly
    icon.name: iconName
    icon.width: iconSize
    icon.height: iconSize
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: title
    Accessible.description: {
        const parts = []
        if (root.running) parts.push(qsTr("Running"))
        if (root.updateApplying) parts.push(qsTr("Installing updates"))
        else if (root.updateCount > 0) parts.push(root.updateSecurityCount > 0
            ? (root.updateCount === 1 ? qsTr("1 security update available")
                : qsTr("%n security updates available", "", root.updateCount))
            : (root.updateCount === 1 ? qsTr("1 update available")
                : qsTr("%n updates available", "", root.updateCount)))
        return parts.join(". ")
    }
    onClicked: {
        feedback.play()
        root.activated()
    }
    onEnabledChanged: if (!enabled) feedback.reset()
    onVisibleChanged: if (!visible) feedback.reset()
    Accessible.onPressAction: root.clicked()

    LauncherClickFeedback {
        id: feedback
        iconSize: root.iconSize
        duration: root.clickDuration
        motionEnabled: !root.reducedMotion && root.enabled && root.visible
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()

    // Keep a fixed high-resolution source and animate only scene transforms.
    contentItem: Item {
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            objectName: "launcher-theme-icon"
            anchors.centerIn: parent
            width: root.highQualityIconSize
            height: width
            source: root.iconName
            roundToIconSize: false
            smooth: true
            scale: root.iconSize / root.highQualityIconSize
            Accessible.ignored: true
        }
    }


    background: LauncherHighlight {
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: root.iconSize + root.metrics.borderWidth * 2
        height: width
        resolutionScale: root.visualIconScale
        hovered: root.hovered
        focused: root.visualFocus
        pressed: root.down
        highlightColor: root.palette.highlight
        strokeWidth: root.metrics.borderWidth
    }
    // The outline is above the icon; the translucent hover fill stays below it.
    LauncherHighlight {
        objectName: "launcher-focus-outline"
        x: root.background.x
        y: root.background.y
        width: root.background.width
        height: root.background.height
        z: 1
        visible: root.visualFocus
        outlineOnly: true
        focused: root.visualFocus
        highlightColor: root.palette.highlight
        strokeWidth: root.metrics.borderWidth
        resolutionScale: root.visualIconScale
    }

    LauncherTooltip {
        id: balloon
        objectName: "launcher-tooltip"
        parent: root.parent
        text: root.title
        font: root.font
        palette: root.palette
        visible: root.tooltipsEnabled && root.hovered && root.enabled
        tailEdge: root.dockEdge === "left" ? "left" : root.dockEdge === "right" ? "right" : "bottom"
        x: root.dockEdge === "left" ? root.iconTopCenter.x + root.iconSize * root.visualIconScale / 2 + metrics.gap
            : root.dockEdge === "right" ? root.iconTopCenter.x - root.iconSize * root.visualIconScale / 2 - width - metrics.gap
            : root.iconTopCenter.x - width / 2
        y: root.vertical ? root.iconTopCenter.y + root.iconSize * root.visualIconScale / 2 - height / 2
            : root.iconTopCenter.y - height - metrics.gap
    }
    // Child of the tile: the existing magnification scale and translate carry the
    // badge with the icon, so it can never lag behind the wave.
    LauncherBadge {
        count: root.updateCount
        securityCount: root.updateSecurityCount
        applying: root.updateApplying
        baseSize: root.metrics.badgeBaseSize
        baseFontPixelSize: root.metrics.badgeFontPixelSize
        maximumScale: root.maximumIconScale
        motionEnabled: !root.reducedMotion && root.visible && root.enabled
        // Lower-right icon corner, in tile coordinates, with a small overlap:
        // the corner KDE gives its update notification dots, clear of the
        // upper-right area reserved for the window controls.
        anchorX: root.width / 2 + root.iconSize / 2 - root.metrics.badgeInset
        anchorY: root.height / 2 + root.iconSize / 2 - root.metrics.badgeInset
        z: 2
        objectName: "launcher-update-badge-" + root.appId
    }
    Rectangle {
        id: runningDot
        objectName: "launcher-running-marker-" + root.appId
        parent: root.parent
        visible: root.running && root.visible
        width: root.metrics.runningMarkerSize
        height: width
        radius: width / 2
        antialiasing: true
        color: root.palette.windowText
        opacity: 0.75
        x: root.x + root.width / 2 + root.iconOffsetX - width / 2
        y: root.vertical ? root.iconTopCenter.y + root.iconSize * root.visualIconScale
            + (root.metrics.bottomContentPadding - height) / 2
            : root.y + root.height + (root.metrics.bottomContentPadding - height) / 2
        Accessible.ignored: true
    }
}
