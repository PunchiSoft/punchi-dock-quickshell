// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// Scroll indicator of the popup family: a thumb with no trough that fades out
// while the view rests. Consumers reserve the strip it paints in only when their
// content really scrolls, so the surface collapses back to its content and no
// row runs under the thumb.
ScrollBar {
    id: root

    objectName: "popupScrollBar"
    property bool motionEnabled: true
    // Settings pages keep the indicator visible at rest; popups keep the
    // original fade while the pointer is away.
    property bool alwaysVisible: false
    property int thickness: 6

    readonly property int gutterWidth: root.thickness + Kirigami.Units.smallSpacing * 2
    readonly property color thumbColor: root.alwaysVisible || root.active
        || root.hovered || root.pressed
        ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
    readonly property bool needed: root.size < 1

    policy: ScrollBar.AsNeeded
    padding: 0
    implicitWidth: root.thickness
    opacity: root.alwaysVisible || root.active || root.hovered || root.pressed ? 1 : 0
    background: null
    contentItem: Rectangle {
        implicitWidth: root.thickness
        implicitHeight: root.thickness
        radius: width / 2
        color: root.thumbColor
        opacity: root.alwaysVisible && !root.active && !root.hovered && !root.pressed ? 0.4 : 1
        visible: root.needed
        Behavior on color {
            enabled: root.motionEnabled
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on opacity {
        enabled: root.motionEnabled
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }
}
