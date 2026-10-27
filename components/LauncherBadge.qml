// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

// Counter attached to a launcher icon. It is a child of the tile so the existing
// magnification scale and translate move it with the icon instead of leaving it
// behind. Glyphs are laid out at the maximum magnification and counter-scaled,
// like the high-resolution icon source, so the number is never an upscaled
// texture.
Item {
    id: root

    objectName: "launcher-update-badge"
    property int count: 0
    property int securityCount: 0
    // PackageKit is applying updates: the disc carries the tray's update-busy
    // glyph instead of the count that is being installed.
    property bool applying: false
    required property int baseSize
    required property int baseFontPixelSize
    required property real maximumScale
    // Icon corner where the badge rests, in tile coordinates.
    property real anchorX: 0
    property real anchorY: 0
    property bool motionEnabled: true

    readonly property bool shown: count > 0 || applying
    readonly property string label: count > 99 ? "99+" : String(count)
    // KDE paints update notifications with ColorScheme-NeutralText (orange,
    // update-medium) and ColorScheme-NegativeText (red, update-high); use the
    // same roles so the badge carries the notification's color instead of the
    // window palette, which is a Qt fallback inside Quickshell. Installing keeps
    // the neutral fill, like the monochrome update-busy tray icon.
    readonly property color fillColor: !applying && securityCount > 0
        ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
    readonly property color contentColor: Kirigami.Theme.textColor
    readonly property real drawingSize: baseSize * maximumScale
    // Halo travel comes from theme spacing instead of a magic amplitude.
    readonly property real haloScale: (drawingSize + Kirigami.Units.smallSpacing * 2) / drawingSize
    property int lastCount: 0

    x: anchorX - drawingSize / 2
    y: anchorY - drawingSize / 2
    width: drawingSize
    height: drawingSize
    scale: 1 / maximumScale
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Accessible.ignored: true

    Behavior on opacity {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: root.shown ? Kirigami.Units.shortDuration : Kirigami.Units.veryShortDuration
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    Rectangle {
        id: disc
        anchors.fill: parent
        radius: width / 2
        color: root.fillColor
        antialiasing: true
    }

    Rectangle {
        id: halo
        objectName: "launcher-update-badge-halo"
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Kirigami.Units.smallSpacing / 2
        border.color: root.fillColor
        opacity: 0
        Accessible.ignored: true
    }

    Text {
        anchors.centerIn: parent
        visible: !root.applying
        width: parent.width - Kirigami.Units.smallSpacing
        text: root.label
        color: root.contentColor
        font.pixelSize: root.baseFontPixelSize * root.maximumScale
        font.weight: Font.DemiBold
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Accessible.ignored: true
    }

    // The tray's own busy icon, sized like the number it replaces and drawn at
    // the badge resolution so it stays sharp while the dock magnifies.
    Kirigami.Icon {
        objectName: "launcher-update-badge-glyph"
        anchors.centerIn: parent
        visible: root.applying
        width: parent.width - Kirigami.Units.smallSpacing
        height: width
        source: "update-busy"
        color: root.contentColor
        Accessible.ignored: true
    }

    // One bounded halo per new count, on theme durations. The number never scales.
    ParallelAnimation {
        id: pulse
        NumberAnimation {
            target: halo; property: "scale"; from: 1; to: root.haloScale
            duration: Kirigami.Units.shortDuration; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: halo; property: "opacity"; from: 0.5; to: 0
            duration: Kirigami.Units.shortDuration; easing.type: Easing.InQuad
        }
    }

    onCountChanged: {
        const previous = lastCount
        lastCount = count
        if (!motionEnabled || !shown || applying || previous <= 0 || count <= previous) return
        halo.scale = 1
        halo.opacity = 0.5
        pulse.restart()
    }
    onApplyingChanged: if (applying) stopMotion()
    onMotionEnabledChanged: if (!motionEnabled) stopMotion()
    onShownChanged: if (!shown) stopMotion()

    function stopMotion(): void {
        pulse.stop()
        halo.opacity = 0
    }
}
