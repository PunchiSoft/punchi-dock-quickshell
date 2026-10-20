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
    property var recentApplications: null
    // Absent service means the fixture has no history source; keep the
    // controls usable so settings-only tests and previews still edit values.
    readonly property bool recentTrackingActive: root.recentApplications === null
        || (root.recentApplications.available && root.recentApplications.trackingEnabled)
    function focusFirst(): void { visibilityControl.forceActiveFocus() }
    spacing: Kirigami.Units.largeSpacing
    SettingsCard {
        objectName: "dockAppearanceCard"
        Layout.fillWidth: true
        title: qsTr("Dock")
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            GridLayout {
                objectName: "settingsScaleLayout"
                Layout.fillWidth: true
                columns: width >= Kirigami.Units.gridUnit * 26 ? 2 : 1
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
        }
        SettingsSeparator { Layout.fillWidth: true }
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Position on screen")
            showSeparator: true
            ComboBox {
                objectName: "dockPosition"
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                model: [qsTr("Bottom"), qsTr("Left"), qsTr("Right")]
                currentIndex: ["bottom", "left", "right"].indexOf(root.settings.dockEdge)
                Accessible.name: qsTr("Position on screen")
                onActivated: root.settings.dockEdge = ["bottom", "left", "right"][currentIndex]
            }
        }
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Visibility")
            showSeparator: false
            ComboBox {
                id: visibilityControl
                objectName: "visibilityMode"
                Layout.minimumWidth: implicitWidth
                Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                model: [qsTr("Always visible"), qsTr("Hide automatically"), qsTr("Dodge windows"), qsTr("Windows go below")]
                currentIndex: PanelModes.modes.indexOf(PanelModes.effective(root.settings.panelMode))
                Accessible.name: qsTr("Visibility")
                onActivated: root.settings.panelMode = PanelModes.modes[currentIndex]
            }
        }
    }
    SettingsCard {
        objectName: "dockStartupCard"
        Layout.fillWidth: true
        title: qsTr("Startup")
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Start with KDE Plasma")
            showSeparator: false
            Switch {
                objectName: "startWithPlasma"
                Accessible.name: qsTr("Start with KDE Plasma")
                enabled: root.autostart !== null && root.autostart.available
                checked: root.autostart !== null && root.autostart.draftEnabled
                onToggled: if (root.autostart !== null) root.autostart.draftEnabled = checked
            }
        }
    }
    SettingsCard {
        objectName: "dockRecentCard"
        Layout.fillWidth: true
        title: qsTr("Recent applications")
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Show recent applications")
            showSeparator: true
            Switch {
                objectName: "recentApplicationsEnabled"
                Accessible.name: qsTr("Show recent applications")
                enabled: root.recentTrackingActive
                checked: root.settings.recentApplicationsEnabled
                onToggled: root.settings.recentApplicationsEnabled = checked
            }
        }
        SettingsRow {
            objectName: "recentApplicationsTrackingRow"
            Layout.fillWidth: true
            visible: root.recentApplications !== null
            text: qsTr("Remember application history in KDE")
            showSeparator: true
            Switch {
                id: trackingSwitch
                objectName: "recentApplicationsTracking"
                Accessible.name: qsTr("Remember application history in KDE")
                checked: root.recentApplications !== null && root.recentApplications.trackingEnabled
                onToggled: {
                    const service = root.recentApplications
                    if (service === null) return
                    service.setTrackingEnabled(checked)
                    // The gesture breaks the declarative binding; KDE stays the
                    // source of truth for external changes.
                    checked = Qt.binding(function() { return service.trackingEnabled })
                }
            }
        }
        SettingsRow {
            objectName: "recentApplicationsKdeRow"
            Layout.fillWidth: true
            visible: root.recentApplications !== null
            text: qsTr("KDE recent files options")
            showSeparator: true
            Button {
                objectName: "recentApplicationsKdeSettings"
                Accessible.name: qsTr("Open KDE Recent Files settings")
                text: qsTr("Open settings")
                onClicked: root.recentApplications.openTrackingSettings()
            }
        }
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Applications to show")
            showSeparator: false
            SpinBox {
                objectName: "recentApplicationsCount"
                Accessible.name: qsTr("Applications to show")
                from: 1
                to: 20
                value: root.settings.recentApplicationsCount
                enabled: root.settings.recentApplicationsEnabled && root.recentTrackingActive
                onValueModified: root.settings.recentApplicationsCount = value
            }
        }
        Label {
            objectName: "recentApplicationsUnavailableNote"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !root.recentTrackingActive
            text: qsTr("KDE is not saving application history. Set System Settings → Recent Files to remember applications to fill this list.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }
    SettingsCard {
        objectName: "dockMotionCard"
        Layout.fillWidth: true
        title: qsTr("Animations")
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Click bounce")
            showSeparator: true
            Switch {
                objectName: "bounceEnabled"
                Accessible.name: qsTr("Click bounce")
                checked: root.settings.bounceEnabled
                onToggled: root.settings.bounceEnabled = checked
            }
        }
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Reduced motion")
            showSeparator: false
            Switch {
                objectName: "reducedMotion"
                Accessible.name: qsTr("Reduced motion")
                checked: root.settings.reducedMotion
                onToggled: root.settings.reducedMotion = checked
            }
        }
    }
}
