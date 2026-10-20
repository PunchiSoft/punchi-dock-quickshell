// SPDX-License-Identifier: GPL-3.0-or-later
// Hover surface shared by popup rows. It reproduces Punchi Menu's default hover
// motion: the row pulses to 1.03 and back on every pointer entry, while the fill
// fades. Leaving mid-pulse settles to 1.0, and reduced motion reaches the same
// states without scaling.
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property bool hovered: false
    property bool selected: false
    property bool focused: false
    property bool pressed: false
    property bool motionEnabled: true
    property color highlightColor: Kirigami.Theme.highlightColor
    property real hoverOpacity: 0.2
    property real selectedOpacity: hoverOpacity
    // Keyboard focus paints a ring by default; a fill here would hide the
    // difference between focus and pointer hover.
    property real focusedOpacity: 0
    property real pressedOpacity: 0.3
    property int focusRingWidth: 0
    property bool ringOnHover: false
    property real motionScale: 1
    property real pressScale: 1

    // Rows apply this value to the item they pulse, never to the fill itself, so
    // the rounded surface and its ring stay crisp. Press travels through the same
    // value, so one interrupted gesture always ends at 1.
    readonly property real visualScale: motionEnabled ? motionScale * pressScale : 1

    // Doubling the theme's short duration keeps the user's animation-speed
    // preference instead of clamping it to a fixed floor.
    readonly property int fadeDuration: motionEnabled
        ? Math.round(Kirigami.Units.shortDuration * 2) : 0
    readonly property real fillOpacity: pressed ? pressedOpacity
        : hovered ? hoverOpacity
        : selected ? selectedOpacity
        : focused ? focusedOpacity
        : 0

    color: fillOpacity > 0
        ? Qt.alpha(highlightColor, Math.max(0, Math.min(1, fillOpacity)))
        : "transparent"
    border.color: highlightColor
    border.width: (focused && focusRingWidth > 0)
        || (ringOnHover && (hovered || pressed)) ? focusRingWidth : 0
    antialiasing: true
    Accessible.ignored: true

    function stopScaleAnimations(): void {
        if (!settleAnimation || !pulseAnimation) return
        settleAnimation.stop()
        pulseAnimation.stop()
    }

    // Same profile as Punchi Menu's pulse: restart the curve on every entry and
    // settle from the current value when the pointer leaves.
    function updateHoverAnimation(): void {
        if (!settleAnimation || !pulseAnimation) return
        stopScaleAnimations()
        if (!root.motionEnabled) {
            root.motionScale = 1
            return
        }
        if (!root.hovered) {
            settleAnimation.restart()
            return
        }
        pulseAnimation.restart()
    }

    onHoveredChanged: root.updateHoverAnimation()
    onMotionEnabledChanged: root.updateHoverAnimation()
    onPressedChanged: root.pressScale = root.pressed ? 0.97 : 1

    Behavior on color {
        enabled: root.fadeDuration > 0
        ColorAnimation {
            duration: root.fadeDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on pressScale {
        enabled: root.motionEnabled
        NumberAnimation {
            // Zero-duration animators are not reliable; 1 ms is the minimum.
            duration: Math.max(1, Kirigami.Units.veryShortDuration)
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: settleAnimation
        target: root
        property: "motionScale"
        to: 1
        duration: 100
        easing.type: Easing.OutCubic
    }

    // Punchi Menu's reference hover pulse: 3% rise in 95 ms and a 125 ms return.
    // The values are kept as the reference profile rather than derived, so the
    // dock's popups feel the same as the menu they came from.
    SequentialAnimation {
        id: pulseAnimation
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1.03
            duration: 95
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "motionScale"
            to: 1
            duration: 125
            easing.type: Easing.InOutCubic
        }
    }
}
