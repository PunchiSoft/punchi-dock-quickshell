// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PanelModes.js" as PanelModes

ColumnLayout {
    id: root
    required property ShellSettings settings
    function focusFirst(): void { visibilityControl.forceActiveFocus() }
    spacing: Kirigami.Units.mediumSpacing
    Label { text: qsTr("General"); font.bold: true }
        ComboBox {
            id: visibilityControl
            objectName: "visibilityMode"
            Layout.fillWidth: true
            model: [qsTr("Always visible"), qsTr("Hide automatically"), qsTr("Dodge windows"), qsTr("Windows go below")]
            currentIndex: PanelModes.modes.indexOf(PanelModes.effective(root.settings.panelMode))
            Accessible.name: qsTr("Visibility")
            onActivated: root.settings.panelMode = PanelModes.modes[currentIndex]
        }
        Label {
            text: qsTr("Icon size: %1%").arg(root.settings.sizePercent)
            Layout.topMargin: Kirigami.Units.largeSpacing
        }
        Slider {
            objectName: "iconSize"
            Layout.fillWidth: true
            from: 50; to: 150; stepSize: 5
            value: root.settings.sizePercent
            Accessible.name: qsTr("Icon size")
            onMoved: root.settings.sizePercent = Math.round(value)
        }
        Switch {
            Layout.topMargin: Kirigami.Units.largeSpacing
            objectName: "magnification"
            text: qsTr("Magnification")
            checked: root.settings.magnificationEnabled
            onToggled: root.settings.magnificationEnabled = checked
        }
        Label { text: qsTr("Zoom scale: %1%").arg(Math.round(root.settings.maximumIconScale * 100)) }
        Slider {
            objectName: "zoomScale"
            Layout.fillWidth: true
            enabled: root.settings.magnificationEnabled
            from: 100; to: 300; stepSize: 10
            value: root.settings.maximumIconScale * 100
            Accessible.name: qsTr("Zoom scale")
            onMoved: root.settings.maximumIconScale = value / 100
        }
        Switch {
            Layout.topMargin: Kirigami.Units.largeSpacing
            objectName: "bounceEnabled"
            text: qsTr("Click bounce")
            checked: root.settings.bounceEnabled
            onToggled: root.settings.bounceEnabled = checked
        }
        Switch {
            text: qsTr("Reduced motion")
            checked: root.settings.reducedMotion
            onToggled: root.settings.reducedMotion = checked
        }
    Item { Layout.fillHeight: true }
}
