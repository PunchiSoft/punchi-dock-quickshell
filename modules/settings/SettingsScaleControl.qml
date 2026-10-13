// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property string title: ""
    property string minimumText: ""
    property string nearMinimumText: ""
    // A descriptive low-range label, independent of the numeric input step.
    property real nearMinimumPosition: 0.15
    property string maximumText: ""
    property string controlName: ""
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias value: slider.value
    signal moved(real value)
    spacing: Kirigami.Units.smallSpacing
    Label { text: root.title; textFormat: Text.PlainText }
    Slider {
        id: slider
        objectName: root.controlName
        Layout.fillWidth: true
        Kirigami.StyleHints.tickMarkStepSize: -1
        Accessible.name: root.title
        Accessible.description: qsTr("%1%").arg(Math.round(value))
        onMoved: root.moved(value)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                const boundary = event.key === Qt.Key_Home ? from : to
                if (value !== boundary) root.moved(boundary)
                event.accepted = true
            }
        }
    }
    Item {
        id: captions
        Layout.fillWidth: true
        implicitHeight: Math.max(minimumLabel.implicitHeight, nearMinimumLabel.implicitHeight,
                                 maximumLabel.implicitHeight)
        readonly property real nearMinimumX: Math.max(
            minimumLabel.width + Kirigami.Units.largeSpacing,
            Math.min(width - maximumLabel.width - Kirigami.Units.largeSpacing - nearMinimumLabel.width,
                     slider.leftPadding + (slider.handle ? slider.handle.width / 2 : 0)
                     + Math.max(0, slider.availableWidth - (slider.handle ? slider.handle.width : 0))
                       * Math.max(0, Math.min(1, root.nearMinimumPosition))
                     - nearMinimumLabel.width / 2))
        Label {
            id: minimumLabel
            objectName: root.controlName + "MinimumLabel"
            x: slider.mirrored ? captions.width - width : 0
            text: root.minimumText
            font: Kirigami.Theme.smallFont
        }
        Label {
            id: nearMinimumLabel
            objectName: root.controlName + "NearMinimumLabel"
            x: slider.mirrored ? captions.width - captions.nearMinimumX - width : captions.nearMinimumX
            text: root.nearMinimumText
            visible: text.length > 0
            font: Kirigami.Theme.smallFont
        }
        Label {
            id: maximumLabel
            objectName: root.controlName + "MaximumLabel"
            x: slider.mirrored ? 0 : captions.width - width
            text: root.maximumText
            font: Kirigami.Theme.smallFont
        }
    }
}
