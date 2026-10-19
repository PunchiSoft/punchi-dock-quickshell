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
    property var autostart: null
    function focusFirst(): void { visibilityControl.forceActiveFocus() }
    spacing: Kirigami.Units.largeSpacing
    Kirigami.Heading { text: qsTr("General"); level: 1 }
    Kirigami.Heading { text: qsTr("Appearance"); level: 3 }
    RowLayout {
        Layout.fillWidth: true
        Label { id: positionLabel; text: qsTr("Position on screen"); Layout.fillWidth: true }
        ComboBox {
            objectName: "dockPosition"
            model: [qsTr("Bottom"), qsTr("Left"), qsTr("Right")]
            currentIndex: ["bottom", "left", "right"].indexOf(root.settings.dockEdge)
            Accessible.name: positionLabel.text
            onActivated: root.settings.dockEdge = ["bottom", "left", "right"][currentIndex]
        }
    }
    GridLayout {
        objectName: "settingsScaleLayout"
        Layout.fillWidth: true
        columns: width >= Kirigami.Units.gridUnit * 24 ? 2 : 1
        columnSpacing: Kirigami.Units.largeSpacing * 2
        rowSpacing: Kirigami.Units.largeSpacing
        SettingsScaleControl {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            title: qsTr("Size")
            minimumText: qsTr("Small")
            maximumText: qsTr("Large")
            controlName: "iconSize"
            from: 50; to: 150; stepSize: 5
            value: root.settings.sizePercent
            onMoved: function(value) { root.settings.sizePercent = Math.round(value) }
        }
        SettingsScaleControl {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            title: qsTr("Magnification")
            minimumText: qsTr("No")
            nearMinimumText: qsTr("Small")
            maximumText: qsTr("Large")
            controlName: "zoomScale"
            from: 100; to: 300; stepSize: 10
            value: root.settings.magnificationEnabled ? root.settings.maximumIconScale * 100 : 100
            onMoved: function(value) {
                root.settings.maximumIconScale = value / 100
                root.settings.magnificationEnabled = value > 100
            }
        }
    }
    ToolSeparator { orientation: Qt.Horizontal; Layout.fillWidth: true }
    Kirigami.Heading { text: qsTr("Behavior"); level: 3 }
    RowLayout {
        Layout.fillWidth: true
        Label { id: visibilityLabel; text: qsTr("Visibility"); Layout.fillWidth: true }
        ComboBox {
            id: visibilityControl
            objectName: "visibilityMode"
            Layout.minimumWidth: implicitWidth
            model: [qsTr("Always visible"), qsTr("Hide automatically"), qsTr("Dodge windows"), qsTr("Windows go below")]
            currentIndex: PanelModes.modes.indexOf(PanelModes.effective(root.settings.panelMode))
            Accessible.name: visibilityLabel.text
            onActivated: root.settings.panelMode = PanelModes.modes[currentIndex]
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { id: autostartLabel; text: qsTr("Start with KDE Plasma"); Layout.fillWidth: true }
        Switch {
            objectName: "startWithPlasma"
            Accessible.name: autostartLabel.text
            enabled: root.autostart !== null && root.autostart.available
            checked: root.autostart !== null && root.autostart.draftEnabled
            onToggled: if (root.autostart !== null) root.autostart.draftEnabled = checked
        }
    }
    ToolSeparator { orientation: Qt.Horizontal; Layout.fillWidth: true }
    Kirigami.Heading { text: qsTr("Animations"); level: 3 }
    RowLayout {
        Layout.fillWidth: true
        Label { id: bounceLabel; text: qsTr("Click bounce"); Layout.fillWidth: true }
        Switch {
            objectName: "bounceEnabled"
            Accessible.name: bounceLabel.text
            checked: root.settings.bounceEnabled
            onToggled: root.settings.bounceEnabled = checked
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { id: motionLabel; text: qsTr("Reduced motion"); Layout.fillWidth: true }
        Switch {
            objectName: "reducedMotion"
            Accessible.name: motionLabel.text
            checked: root.settings.reducedMotion
            onToggled: root.settings.reducedMotion = checked
        }
    }
}
