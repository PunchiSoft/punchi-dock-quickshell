// SPDX-License-Identifier: GPL-3.0-or-later
// Hover surface shared by popup rows. It paints the native Breeze emphasis: a
// pointer or keyboard band of `alpha(highlightColor, 0.3)` with a hairline of the
// same colour, and the solid `highlightColor` with highlighted text when the row
// is the selection. The pulse on every pointer entry is the reference motion;
// reduced motion reaches the same states without scaling.
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property bool hovered: false
    property bool selected: false
    // Keyboard focus paints the same band as the pointer, as the native menu
    // does; it never adds a second fill on top of the hover.
    property bool focused: false
    property bool pressed: false
    property bool motionEnabled: true
    property color hoverColor: Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
    property color hoverBorderColor: Kirigami.Theme.highlightColor
    property color selectedColor: Kirigami.Theme.highlightColor
    property real borderThickness: Math.max(1, Math.round(Kirigami.Units.smallSpacing / 4))
    property real motionScale: 1
    property real pressScale: 1
    radius: Kirigami.Units.cornerRadius

    // A selection and a press use the solid highlight; the pointer band stays
    // translucent, so the two states never read as the same fill.
    readonly property bool marked: root.pressed || root.selected
    readonly property bool banded: root.marked || root.hovered || root.focused
    // Rows apply this value to the item they pulse, never to the fill itself, so
    // the rounded surface and its border stay crisp. Press travels through the
    // same value, so one interrupted gesture always ends at 1.
    readonly property real visualScale: motionEnabled ? motionScale * pressScale : 1
    // Doubling the theme's short duration keeps the user's animation-speed
    // preference instead of clamping it to a fixed floor.
    readonly property int fadeDuration: motionEnabled
        ? Math.round(Kirigami.Units.shortDuration * 2) : 0

    color: root.marked ? root.selectedColor : root.banded ? root.hoverColor : "transparent"
    border.color: root.marked ? root.selectedColor : root.hoverBorderColor
    border.width: root.banded ? root.borderThickness : 0
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
    Behavior on border.color {
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
