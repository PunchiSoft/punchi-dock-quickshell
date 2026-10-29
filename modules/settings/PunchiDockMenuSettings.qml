// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"

// Fullscreen menu settings. They live here, in their own settings category,
// instead of inside the menu: the plasmoid embedded them because a Plasma
// applet has no separate settings window, and this shell does not share that
// limitation.
ColumnLayout {
    id: root
    objectName: "settingsDockMenu"

    required property PunchiShellSettings settings

    readonly property var hoverAnimationOptions: [
        {text: qsTr("None"), value: "none"},
        {text: qsTr("Individual"), value: "individual"},
        {text: qsTr("Pulse"), value: "pulse"},
        {text: qsTr("Bounce"), value: "bounce"}
    ]
    readonly property var closeButtonOptions: [
        {text: qsTr("Right"), value: "right"},
        {text: qsTr("Left"), value: "left"}
    ]

    function hoverAnimationIndex(): int {
        for (let index = 0; index < root.hoverAnimationOptions.length; ++index)
            if (root.hoverAnimationOptions[index].value === root.settings.menuHoverAnimation)
                return index
        return 2
    }
    function closeButtonIndex(): int {
        return root.settings.menuCloseButtonPosition === "left" ? 1 : 0
    }
    function focusFirst(): void {
        opacityControl.focusControl()
    }

    spacing: Kirigami.Units.largeSpacing

    PunchiSettingsCard {
        objectName: "dockMenuAppearanceCard"
        Layout.fillWidth: true
        title: qsTr("Menu appearance")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Background blur")
                showSeparator: true
                Switch {
                    objectName: "menuBackgroundBlurEnabled"
                    Accessible.name: qsTr("Menu background blur")
                    checked: root.settings.menuBackgroundBlurEnabled
                    onToggled: root.settings.menuBackgroundBlurEnabled = checked
                }
            }
            PunchiSettingsScaleControl {
                id: opacityControl
                Layout.fillWidth: true
                title: qsTr("Background opacity")
                minimumText: qsTr("Translucent")
                maximumText: qsTr("Solid")
                controlName: "menuBackgroundOpacity"
                from: 50; to: 100; stepSize: 5
                value: Math.round(root.settings.menuBackgroundOpacity * 100)
                onMoved: function(value) { root.settings.menuBackgroundOpacity = value / 100 }
            }
            PunchiSettingsSeparator { Layout.fillWidth: true }
            PunchiSettingsScaleControl {
                id: iconScaleControl
                Layout.fillWidth: true
                title: qsTr("Icon size")
                minimumText: qsTr("Small")
                maximumText: qsTr("Large")
                controlName: "menuIconScale"
                from: 75; to: 150; stepSize: 5
                value: Math.round(root.settings.menuIconScale * 100)
                onMoved: function(value) { root.settings.menuIconScale = value / 100 }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Application labels")
                showSeparator: true
                Switch {
                    objectName: "menuShowLabels"
                    Accessible.name: qsTr("Application labels")
                    checked: root.settings.menuShowLabels
                    onToggled: root.settings.menuShowLabels = checked
                }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Distribution name")
                showSeparator: true
                Switch {
                    objectName: "menuShowDistributionName"
                    Accessible.name: qsTr("Distribution name")
                    checked: root.settings.menuShowDistributionName
                    onToggled: root.settings.menuShowDistributionName = checked
                }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Page arrows")
                showSeparator: false
                Switch {
                    objectName: "menuShowPageArrows"
                    Accessible.name: qsTr("Page arrows")
                    checked: root.settings.menuShowPageArrows
                    onToggled: root.settings.menuShowPageArrows = checked
                }
            }
        }
    }

    PunchiSettingsCard {
        objectName: "dockMenuBehaviourCard"
        Layout.fillWidth: true
        title: qsTr("Menu behaviour")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Hover animation")
                showSeparator: true
                ComboBox {
                    objectName: "menuHoverAnimation"
                    Accessible.name: qsTr("Hover animation")
                    model: root.hoverAnimationOptions.map(option => option.text)
                    currentIndex: root.hoverAnimationIndex()
                    onActivated: function(index) {
                        root.settings.menuHoverAnimation
                            = root.hoverAnimationOptions[index].value
                    }
                }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Close button")
                showSeparator: false
                ComboBox {
                    objectName: "menuCloseButtonPosition"
                    Accessible.name: qsTr("Close button position")
                    model: root.closeButtonOptions.map(option => option.text)
                    currentIndex: root.closeButtonIndex()
                    onActivated: function(index) {
                        root.settings.menuCloseButtonPosition
                            = root.closeButtonOptions[index].value
                    }
                }
            }
        }
    }
}
