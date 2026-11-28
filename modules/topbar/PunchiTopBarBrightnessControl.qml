// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Brightness of the provider-selected display. The slider only writes while a
// display with a real range exists; the value shown always comes from the
// provider, so a rejected or clamped write does not leave a false position.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarBrightnessControl"
    readonly property bool ready: root.control !== null && root.control.hasControl === true
    readonly property int percent: root.control ? root.control.percent : 0
    spacing: Kirigami.Units.smallSpacing
    function focusFirst(): void { slider.forceActiveFocus(Qt.PopupFocusReason) }
    PunchiTopBarControlRow {
        iconName: root.control && root.control.hasControl
            ? (root.percent < 50 ? "brightness-low" : "brightness-high")
            : "brightness-low"
        title: qsTr("Brightness")
        statusText: root.control ? root.control.statusText : qsTr("Unavailable")
        Label {
            objectName: "topBarBrightnessValue"
            text: root.ready ? qsTr("%1%").arg(root.percent) : ""
            font: Kirigami.Theme.defaultFont
            color: Kirigami.Theme.textColor
        }
    }
    Slider {
        id: slider
        objectName: "topBarBrightnessSlider"
        Layout.fillWidth: true
        enabled: root.ready
        from: 0
        to: 100
        stepSize: 1
        Accessible.name: qsTr("Brightness")
        onMoved: if (root.control) root.control.setPercent(value)
        onPressedChanged: {
            if (!root.control) return
            if (pressed) root.control.beginGesture()
            else root.control.endGesture()
        }
    }
    readonly property Connections controlChanges: Connections {
        target: root.control
        function onPercentChanged() { if (!slider.pressed) slider.value = root.control.percent }
        function onHasControlChanged() { if (!slider.pressed) slider.value = root.control.percent }
    }
    Component.onCompleted: slider.value = root.percent
}
