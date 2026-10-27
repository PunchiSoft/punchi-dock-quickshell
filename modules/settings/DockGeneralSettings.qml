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
    property var updates: null
    // Names the sources that really answered, so the note never promises a
    // source the distribution does not provide. Hidden while nothing is known.
    readonly property string updateSourcesText: {
        if (root.updates === null) return ""
        const sources = root.updates.availableSources || []
        if (sources.length === 0) return ""
        const names = []
        for (const source of sources) {
            if (source === "system") {
                const backend = root.updates.backendName || ""
                names.push(backend.length > 0 ? backend : qsTr("system packages"))
            } else if (source === "flatpak") {
                names.push(qsTr("Flatpak"))
            } else if (source === "firmware") {
                names.push(qsTr("firmware"))
            }
        }
        return qsTr("Updates from %1").arg(names.join(" · "))
    }
    // The note follows KDE's own preference only. Gating a dock switch on the
    // service state made it impossible to turn the list back on, because
    // hiding the list is what stops the service from being queried.
    readonly property bool kdeTrackingActive: root.recentApplications === null
        || root.recentApplications.trackingEnabled
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
            showSeparator: true
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
                    && !root.autostart.trial
                checked: root.autostart !== null && root.autostart.draftEnabled
                onToggled: if (root.autostart !== null) root.autostart.draftEnabled = checked
            }
        }
        Label {
            objectName: "startupTrialNote"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.autostart !== null && root.autostart.trial
            text: qsTr("Available only when Punchi Dock Quickshell is installed for this user. A trial run cannot start it at sign-in.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }
    SettingsCard {
        objectName: "dockUpdatesCard"
        Layout.fillWidth: true
        title: qsTr("Updates")
        SettingsRow {
            Layout.fillWidth: true
            text: qsTr("Show available updates")
            showSeparator: false
            Switch {
                objectName: "updateBadgeEnabled"
                Accessible.name: qsTr("Show available updates")
                checked: root.settings.updateBadgeEnabled
                onToggled: root.settings.updateBadgeEnabled = checked
            }
        }
        Label {
            objectName: "updateBadgeSourcesNote"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: root.updateSourcesText.length > 0
            text: root.updateSourcesText
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
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
                enabled: root.settings.recentApplicationsEnabled
                onValueModified: root.settings.recentApplicationsCount = value
            }
        }
        Label {
            objectName: "recentApplicationsUnavailableNote"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !root.kdeTrackingActive
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
