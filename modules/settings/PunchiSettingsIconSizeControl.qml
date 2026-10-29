// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Glyph size of one popup presentation. The slider keeps the stored value on an
// even pixel count and the readout states the base glyph the presentation will
// use, so a size that suits the grid can be told apart from one that suits the
// arc.
ColumnLayout {
    id: root
    property string title: ""
    property string controlName: ""
    property alias from: slider.from
    property alias to: slider.to
    property alias value: slider.value
    signal moved(real value)
    function focusControl(): void { slider.forceActiveFocus() }
    spacing: Kirigami.Units.smallSpacing
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Label {
            Layout.fillWidth: true
            text: root.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        Label {
            objectName: root.controlName + "Value"
            text: qsTr("%1 px").arg(Math.round(root.value))
            textFormat: Text.PlainText
            font: Kirigami.Theme.smallFont
        }
    }
    Slider {
        id: slider
        objectName: root.controlName
        Layout.fillWidth: true
        stepSize: 2
        Accessible.name: root.title
        Accessible.description: qsTr("%1 px").arg(Math.round(value))
        onMoved: root.moved(value)
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                const boundary = event.key === Qt.Key_Home ? from : to
                if (value !== boundary) root.moved(boundary)
                event.accepted = true
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label {
            objectName: root.controlName + "MinimumLabel"
            text: qsTr("%1 px").arg(root.from)
            font: Kirigami.Theme.smallFont
        }
        Item { Layout.fillWidth: true }
        Label {
            objectName: root.controlName + "MaximumLabel"
            text: qsTr("%1 px").arg(root.to)
            font: Kirigami.Theme.smallFont
        }
    }
}
