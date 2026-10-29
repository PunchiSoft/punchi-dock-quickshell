// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami

// Window control drawn with the buttons of the user's Aurorae decoration.
// Appearance belongs to the decoration; the action belongs to the consumer, which
// names the role it needs. Without a compatible theme the control falls back to a
// theme icon, so it is never invisible.
ToolButton {
    id: root

    // "close", "minimize", "maximize" or "restore".
    required property string role
    // Resolved by the consumer so the binding follows decoration changes.
    property string decorationImagePath: ""
    property size decorationButtonSize: Qt.size(16, 16)
    // The decoration's own vocabulary: active window versus inactive window.
    property bool decorationActive: Window.window ? Window.window.active : true
    // Pointing at a control is not the same as owning the window focus.
    property bool activePointerStates: false
    property string fallbackIconName: "window-close"
    property int fallbackIconSize: Kirigami.Units.iconSizes.small

    readonly property bool usingDecoration: themedGlyph.imagePath.length > 0
        && themedGlyph.hasElementPrefix("active")

    implicitWidth: Math.max(root.fallbackIconSize + Kirigami.Units.smallSpacing * 2,
        root.decorationButtonSize.width + Kirigami.Units.smallSpacing * 2)
    implicitHeight: Math.max(root.fallbackIconSize + Kirigami.Units.smallSpacing * 2,
        root.decorationButtonSize.height + Kirigami.Units.smallSpacing * 2)
    padding: 0
    hoverEnabled: true
    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    // The decoration paints its own frame; the Plasma background only belongs to
    // the fallback, and focus keeps a separate indicator.
    Binding {
        target: root.background
        property: "opacity"
        value: root.usingDecoration ? 0 : 1
        when: root.background !== null
    }

    contentItem: Item {
        KSvg.FrameSvgItem {
            id: themedGlyph
            anchors.centerIn: parent
            width: root.decorationButtonSize.width
            height: root.decorationButtonSize.height
            imagePath: root.decorationImagePath
            enabledBorders: KSvg.FrameSvg.NoBorder
            visible: root.usingDecoration
            prefix: {
                if (!root.enabled)
                    return [root.decorationActive ? "deactivated" : "deactivated-inactive",
                        "inactive", "active"]
                if (root.down) {
                    return root.activePointerStates
                        ? ["pressed", "pressed-inactive", "active"]
                        : [root.decorationActive ? "pressed" : "pressed-inactive",
                            "pressed", "active"]
                }
                if (root.hovered) {
                    return root.activePointerStates
                        ? ["hover", "hover-inactive", "active"]
                        : [root.decorationActive ? "hover" : "hover-inactive",
                            "hover", "active"]
                }
                return [root.decorationActive ? "active" : "inactive", "active"]
            }
            Accessible.ignored: true
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.fallbackIconSize
            height: root.fallbackIconSize
            source: root.fallbackIconName
            color: Kirigami.Theme.textColor
            visible: !root.usingDecoration
            Accessible.ignored: true
        }
    }

    // Keyboard focus must stay visible without masquerading as pointer hover.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Kirigami.Units.cornerRadius
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        visible: root.visualFocus
        Accessible.ignored: true
    }
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
}
