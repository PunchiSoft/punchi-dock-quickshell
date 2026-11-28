// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One top-panel trigger. The content item is built here instead of relying on
// the active Qt Quick Controls style: the Bubble/Breeze style paints a tool
// button through its own background and leaves a custom-background button with
// a zero-width content area, which made the whole bar empty under the system
// style. Icon-only mode keeps the accessible name; hover never takes focus; the
// focus ring stays distinct from the hover fill.
AbstractButton {
    id: root
    property string accessibleName: ""
    property string iconName: ""
    property bool showLabel: true
    property bool motionEnabled: true
    readonly property bool focusVisible: root.activeFocus && root.Window.active
    property bool selected: false
    readonly property color contentColor: root.enabled
        ? (root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor)
        : Kirigami.Theme.disabledTextColor
    objectName: "topBarButton"
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    padding: Kirigami.Units.smallSpacing
    leftPadding: Kirigami.Units.mediumSpacing
    rightPadding: Kirigami.Units.mediumSpacing
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    implicitWidth: contentRow.implicitWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.75,
        contentRow.implicitHeight + topPadding + bottomPadding)
    font: Kirigami.Theme.defaultFont
    Accessible.name: root.accessibleName.length > 0 ? root.accessibleName : root.text
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.clicked()
    contentItem: RowLayout {
        id: contentRow
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            objectName: "topBarButtonIcon"
            source: root.iconName
            visible: root.iconName.length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            Layout.alignment: Qt.AlignVCenter
            color: root.contentColor
            Accessible.ignored: true
        }
        Label {
            objectName: "topBarButtonLabel"
            visible: root.showLabel && root.text.length > 0
            text: root.text
            textFormat: Text.PlainText
            font: root.font
            color: root.contentColor
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
    background: Rectangle {
        objectName: "topBarButtonBackground"
        radius: Kirigami.Units.cornerRadius * 2
        color: root.pressed ? Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
            : root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
            : root.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.14)
            : "transparent"
        border.width: root.focusVisible ? Math.max(1, Kirigami.Units.smallSpacing / 4) : 0
        border.color: Kirigami.Theme.highlightColor
        Behavior on color {
            enabled: root.motionEnabled
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }
}
