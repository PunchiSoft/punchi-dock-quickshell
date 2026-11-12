// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import "../../config"

// Fullscreen menu settings. They live here, in their own settings category,
// instead of inside the menu: the plasmoid embedded them because a Plasma
// applet has no separate settings window, and this shell does not share that
// limitation.
ColumnLayout {
    id: root
    objectName: "settingsDockMenu"

    required property PunchiShellSettings settings
    // The settings view owns the page index; the inline key recorder waits
    // until this page is the one being shown.
    property bool pageActive: false
    property bool updatingShortcut: false

    readonly property var hoverAnimationOptions: [
        {text: qsTr("None"), value: "none"},
        {text: qsTr("Individual"), value: "individual"},
        {text: qsTr("Pulse"), value: "pulse"},
        {text: qsTr("Bounce"), value: "bounce"}
    ]
    readonly property var closeButtonOptions: [
        {text: qsTr("Right"), value: "right"},
        {text: qsTr("Left"), value: "left"},
        {text: qsTr("Hidden"), value: "hidden"}
    ]
    readonly property var applicationOrderOptions: [
        {text: qsTr("Categories"), value: "categories"},
        {text: qsTr("Alphabetical"), value: "alphabetical"},
        {text: qsTr("Manual"), value: "manual"}
    ]

    function hoverAnimationIndex(): int {
        for (let index = 0; index < root.hoverAnimationOptions.length; ++index)
            if (root.hoverAnimationOptions[index].value === root.settings.menuHoverAnimation)
                return index
        return 2
    }
    function closeButtonIndex(): int {
        for (let index = 0; index < root.closeButtonOptions.length; ++index)
            if (root.closeButtonOptions[index].value === root.settings.menuCloseButtonPosition)
                return index
        return 0
    }
    function applicationOrderIndex(): int {
        for (let index = 0; index < root.applicationOrderOptions.length; ++index)
            if (root.applicationOrderOptions[index].value === root.settings.menuApplicationOrder)
                return index
        return 0
    }
    function focusFirst(): void {
        opacityControl.focusControl()
    }
    function syncShortcutEditor(): void {
        if (!shortcutEditorLoader.item) return
        updatingShortcut = true
        // qmllint disable missing-property unresolved-type
        shortcutEditorLoader.item.keySequence = root.settings.menuShortcut
        // qmllint enable missing-property unresolved-type
        updatingShortcut = false
    }

    Connections {
        target: root.settings
        function onMenuShortcutChanged() { root.syncShortcutEditor() }
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
                text: qsTr("Scroll bar")
                showSeparator: false
                Switch {
                    objectName: "menuShowScrollBar"
                    Accessible.name: qsTr("Menu scroll bar")
                    checked: root.settings.menuShowScrollBar
                    onToggled: root.settings.menuShowScrollBar = checked
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
                text: qsTr("Menu shortcut")
                showSeparator: true
                Loader {
                    id: shortcutEditorLoader
                    // StackLayout maps only the current page. Loading the
                    // editor when this page is active keeps the KDE key
                    // recorder out of the other pages and their runtime test.
                    active: root.pageActive
                    sourceComponent: Component {
                        KQuickControls.KeySequenceItem {
                            id: shortcutEditor
                            objectName: "menuShortcutEditor"
                            showCancelButton: true
                            // Keep the Plasma 6.0-compatible properties.
                            // ShortcutPattern arrived in a later KF6 release.
                            // qmllint disable deprecated
                            modifierOnlyAllowed: true
                            modifierlessAllowed: false
                            // qmllint enable deprecated
                            Accessible.name: qsTr("Menu shortcut")
                            onKeySequenceModified: {
                                if (root.updatingShortcut) return
                                // qmllint disable missing-property unresolved-type
                                root.settings.menuShortcut = shortcutEditor.keySequence.toString()
                                // qmllint enable missing-property unresolved-type
                            }
                        }
                    }
                    onItemChanged: if (item) root.syncShortcutEditor()
                }
            }
            Label {
                objectName: "menuShortcutHelp"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: -Kirigami.Units.smallSpacing
                text: qsTr("Meta is the Super or Windows key on most keyboards.")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Show menu button")
                showSeparator: true
                Switch {
                    objectName: "menuShowDockButton"
                    Accessible.name: qsTr("Show menu button")
                    checked: root.settings.menuShowDockButton
                    onToggled: root.settings.menuShowDockButton = checked
                }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Dock over the menu")
                showSeparator: true
                Switch {
                    objectName: "menuShowDock"
                    Accessible.name: qsTr("Dock over the menu")
                    checked: root.settings.menuShowDock
                    onToggled: root.settings.menuShowDock = checked
                }
            }
            PunchiSettingsRow {
                Layout.fillWidth: true
                text: qsTr("Application order")
                showSeparator: true
                ComboBox {
                    objectName: "menuApplicationOrder"
                    Accessible.name: qsTr("Application order")
                    model: root.applicationOrderOptions.map(option => option.text)
                    currentIndex: root.applicationOrderIndex()
                    onActivated: function(index) {
                        root.settings.menuApplicationOrder
                            = root.applicationOrderOptions[index].value
                    }
                }
            }
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
