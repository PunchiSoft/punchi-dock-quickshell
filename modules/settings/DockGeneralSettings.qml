// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PanelModes.js" as PanelModes
import "../../config/ScreenSelection.js" as ScreenSelection

ColumnLayout {
    id: root
    required property ShellSettings settings
    property var autostart: null
    property var recentApplications: null
    property var updates: null
    // Connected screens, injected by the host so this page stays testable
    // without the Quickshell module.
    property var screens: []
    property string primaryScreenName: ""
    property var runningApplications: null
    readonly property var disconnectedScreenKeys: ScreenSelection.disconnectedKeys(
        root.screens, root.settings.selectedScreens)
    // The screen that shows the dock while every saved selection is unplugged.
    readonly property string fallbackScreenKey: ScreenSelection.fallbackKey(
        root.screens, root.settings.screenMode, root.settings.selectedScreens,
        root.primaryScreenName)
    // A single connected screen needs no choice. Keep the row only when it
    // explains a disconnected saved screen or the temporary fallback.
    readonly property bool screenPlacementVisible: ScreenSelection.showsScreenPlacement(
        root.screens, root.settings.screenMode, root.settings.selectedScreens,
        root.primaryScreenName)
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
    function selectionWith(list, key, selected): var {
        const next = (Array.isArray(list) ? list : []).filter(entry => entry !== key)
        if (selected && next.length < 16) next.push(key)
        return next
    }
    function setScreenSelected(key: string, selected: bool): void {
        root.settings.selectedScreens = selectionWith(root.settings.selectedScreens, key, selected)
    }
    // While the saved screens are unplugged, checking one of the connected
    // screens is an explicit move, not an addition to an unusable selection.
    function setScreenChecked(key: string, selected: bool): void {
        if (selected && root.fallbackScreenKey.length > 0) {
            root.settings.selectedScreens = [key]
            return
        }
        root.setScreenSelected(key, selected)
    }
    function setDesktopSelected(key: string, selected: bool): void {
        root.settings.selectedDesktops = selectionWith(root.settings.selectedDesktops, key, selected)
    }
    function setActivitySelected(key: string, selected: bool): void {
        root.settings.selectedActivities = selectionWith(root.settings.selectedActivities, key, selected)
    }
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
    SettingsCard {
        objectName: "dockPlacementCard"
        Layout.fillWidth: true
        title: qsTr("Screens and desktops")
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            SettingsRow {
                objectName: "screenPlacementRow"
                Layout.fillWidth: true
                visible: root.screenPlacementVisible
                text: qsTr("Show dock on")
                showSeparator: root.settings.screenMode !== "selected"
                ComboBox {
                    objectName: "screenMode"
                    Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                    model: [qsTr("All screens"), qsTr("Selected screens")]
                    currentIndex: root.settings.screenMode === "selected" ? 1 : 0
                    Accessible.name: qsTr("Show dock on")
                    onActivated: root.settings.screenMode = currentIndex === 1 ? "selected" : "all"
                }
            }
            ColumnLayout {
                objectName: "screenSelection"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: root.screenPlacementVisible
                    && root.settings.screenMode === "selected"
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    text: qsTr("Screens")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    Accessible.ignored: true
                }
                Repeater {
                    model: root.screens
                    delegate: CheckBox {
                        required property var modelData
                        objectName: "screen-" + modelData.name
                        Layout.fillWidth: true
                        text: ((modelData.model || "").length > 0
                            ? modelData.name + " · " + modelData.model
                            : modelData.name)
                            + (root.fallbackScreenKey === modelData.name
                                ? " · " + qsTr("Fallback") : "")
                        checked: (root.settings.selectedScreens || []).indexOf(modelData.name) >= 0
                        Accessible.name: text
                        // Click only: a fallback marker changes `checked` through the
                        // binding and must not rewrite the saved selection.
                        onClicked: root.setScreenChecked(modelData.name, checked)
                    }
                }
                Repeater {
                    model: root.disconnectedScreenKeys
                    delegate: CheckBox {
                        required property string modelData
                        objectName: "screenMissing-" + modelData
                        Layout.fillWidth: true
                        checked: true
                        enabled: false
                        text: modelData + " · " + qsTr("Not connected")
                        Accessible.name: text
                    }
                }
            }
            SettingsSeparator {
                objectName: "screenPlacementSeparator"
                Layout.fillWidth: true
                visible: root.screenPlacementVisible
                    && root.settings.screenMode === "selected"
            }
            SettingsRow {
                Layout.fillWidth: true
                visible: root.runningApplications !== null && root.runningApplications.available
                text: qsTr("Virtual desktops")
                showSeparator: root.settings.desktopMode !== "selected"
                ComboBox {
                    objectName: "desktopMode"
                    Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                    model: [qsTr("All desktops"), qsTr("Selected desktops")]
                    currentIndex: root.settings.desktopMode === "selected" ? 1 : 0
                    Accessible.name: qsTr("Virtual desktops")
                    onActivated: root.settings.desktopMode = currentIndex === 1 ? "selected" : "all"
                }
            }
            ColumnLayout {
                objectName: "desktopSelection"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: root.settings.desktopMode === "selected"
                    && root.runningApplications !== null && root.runningApplications.available
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    text: qsTr("Desktops")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    Accessible.ignored: true
                }
                Repeater {
                    model: root.runningApplications ? root.runningApplications.virtualDesktops : []
                    delegate: CheckBox {
                        required property var modelData
                        objectName: "desktop-" + modelData.id
                        Layout.fillWidth: true
                        text: (modelData.name || "").length > 0
                            ? modelData.name : String(modelData.id)
                        checked: (root.settings.selectedDesktops || []).indexOf(String(modelData.id)) >= 0
                        Accessible.name: text
                        onCheckedChanged: root.setDesktopSelected(String(modelData.id), checked)
                    }
                }
            }
            SettingsSeparator {
                Layout.fillWidth: true
                visible: root.settings.desktopMode === "selected"
                    && root.runningApplications !== null && root.runningApplications.available
            }
            SettingsRow {
                Layout.fillWidth: true
                visible: root.runningApplications !== null && root.runningApplications.available
                text: qsTr("Activities")
                showSeparator: root.settings.activityMode !== "selected"
                ComboBox {
                    objectName: "activityMode"
                    Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
                    model: [qsTr("All activities"), qsTr("Selected activities")]
                    currentIndex: root.settings.activityMode === "selected" ? 1 : 0
                    Accessible.name: qsTr("Activities")
                    onActivated: root.settings.activityMode = currentIndex === 1 ? "selected" : "all"
                }
            }
            ColumnLayout {
                objectName: "activitySelection"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: root.settings.activityMode === "selected"
                    && root.runningApplications !== null && root.runningApplications.available
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    text: qsTr("Activities")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    Accessible.ignored: true
                }
                Repeater {
                    model: root.runningApplications ? root.runningApplications.activities : []
                    delegate: CheckBox {
                        required property var modelData
                        objectName: "activity-" + modelData.id
                        Layout.fillWidth: true
                        text: (modelData.name || "").length > 0
                            ? modelData.name : String(modelData.id)
                        checked: (root.settings.selectedActivities || []).indexOf(String(modelData.id)) >= 0
                        Accessible.name: text
                        onCheckedChanged: root.setActivitySelected(String(modelData.id), checked)
                    }
                }
            }
            SettingsSeparator {
                Layout.fillWidth: true
                visible: root.settings.activityMode === "selected"
                    && root.runningApplications !== null && root.runningApplications.available
            }
            SettingsRow {
                Layout.fillWidth: true
                text: qsTr("Running indicators follow the desktop")
                showSeparator: false
                Switch {
                    objectName: "runningMarkersFollowDesktop"
                    Accessible.name: qsTr("Running indicators follow the desktop")
                    enabled: root.runningApplications !== null && root.runningApplications.available
                    checked: root.settings.runningMarkersFollowDesktop
                    onCheckedChanged: root.settings.runningMarkersFollowDesktop = checked
                }
            }
            SettingsRow {
                Layout.fillWidth: true
                text: qsTr("Keep the dock visible at a shared edge")
                showSeparator: false
                Switch {
                    objectName: "avoidInnerEdgeAutoHide"
                    Accessible.name: qsTr("Keep the dock visible at a shared edge")
                    checked: root.settings.avoidInnerEdgeAutoHide
                    onCheckedChanged: root.settings.avoidInnerEdgeAutoHide = checked
                }
            }
        }
    }
}
