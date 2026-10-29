// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/ScreenSelection.js" as ScreenSelection

// General settings page. Each card owns the rule it shows and the live service it
// reads; the page only injects those services and forwards the initial focus.
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

    spacing: Kirigami.Units.largeSpacing

    function focusFirst(): void {
        appearanceSettings.focusVisibility()
    }

    DockAppearanceSettings {
        id: appearanceSettings
        settings: root.settings
    }
    DockStartupSettings {
        autostart: root.autostart
    }
    DockUpdatesSettings {
        settings: root.settings
        updates: root.updates
    }
    DockRecentApplicationsSettings {
        settings: root.settings
        recentApplications: root.recentApplications
    }
    DockMotionSettings {
        settings: root.settings
    }
    DockPlacementSettings {
        settings: root.settings
        screens: root.screens
        primaryScreenName: root.primaryScreenName
        runningApplications: root.runningApplications
        disconnectedScreenKeys: root.disconnectedScreenKeys
        fallbackScreenKey: root.fallbackScreenKey
        screenPlacementVisible: root.screenPlacementVisible
    }
}
