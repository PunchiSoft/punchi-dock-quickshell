// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PunchiScreenSelection.js" as PunchiScreenSelection

// General settings page. Each card owns the rule it shows and the live service it
// reads; the page only injects those services and forwards the initial focus.
ColumnLayout {
    id: root
    required property PunchiShellSettings settings
    property var autostart: null
    property var recentApplications: null
    property var updates: null
    // Connected screens, injected by the host so this page stays testable
    // without the Quickshell module.
    property var screens: []
    property string primaryScreenName: ""
    property var runningApplications: null

    readonly property var disconnectedScreenKeys: PunchiScreenSelection.disconnectedKeys(
        root.screens, root.settings.selectedScreens)
    // The screen that shows the dock while every saved selection is unplugged.
    readonly property string fallbackScreenKey: PunchiScreenSelection.fallbackKey(
        root.screens, root.settings.screenMode, root.settings.selectedScreens,
        root.primaryScreenName)
    // A single connected screen needs no choice. Keep the row only when it
    // explains a disconnected saved screen or the temporary fallback.
    readonly property bool screenPlacementVisible: PunchiScreenSelection.showsScreenPlacement(
        root.screens, root.settings.screenMode, root.settings.selectedScreens,
        root.primaryScreenName)

    spacing: Kirigami.Units.largeSpacing

    function focusFirst(): void {
        appearanceSettings.focusVisibility()
    }

    PunchiDockAppearanceSettings {
        id: appearanceSettings
        settings: root.settings
    }
    PunchiDockStartupSettings {
        autostart: root.autostart
    }
    PunchiDockUpdatesSettings {
        settings: root.settings
        updates: root.updates
    }
    PunchiDockRecentApplicationsSettings {
        settings: root.settings
        recentApplications: root.recentApplications
    }
    PunchiDockMotionSettings {
        settings: root.settings
    }
    PunchiDockPlacementSettings {
        settings: root.settings
        screens: root.screens
        primaryScreenName: root.primaryScreenName
        runningApplications: root.runningApplications
        disconnectedScreenKeys: root.disconnectedScreenKeys
        fallbackScreenKey: root.fallbackScreenKey
        screenPlacementVisible: root.screenPlacementVisible
    }
}
