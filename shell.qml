// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import "config"
import Punchi.Kde as Native
import "modules/dock"
import "modules/menu"
import "modules/settings"
import "services"

ShellRoot {
    // Quickshell's reload popup loads its own wrapper components, which log
    // Qt property-cache warnings on this Qt version. Reload outcomes are
    // recorded in the log; only a successful reload suppresses the popup, so a
    // failed reload still shows its error.
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
    }
    PunchiShellSettings {
        id: shellSettings
        panelMode: Quickshell.env("PUNCHI_DOCK_MODE") || "overlay"
    }
    // One catalog, window backend and update tracker serve every dock window.
    PunchiDockServices { id: dockServices; settings: shellSettings }
    // One owner decides which screen holds the fullscreen menu, so the
    // dock item, the IPC commands and the surfaces never disagree.
    PunchiMenuController { id: menuController }
    Native.ScreenInfo { id: screenInfo }
    PunchiScreenPolicy {
        id: screenPolicy
        settings: shellSettings
        connectedScreens: Quickshell.screens
        primaryScreenName: screenInfo.primaryName
    }
    PunchiVirtualDesktopPolicy {
        id: desktopPolicy
        settings: shellSettings
        runningApplications: dockServices.runningApplications
    }
    // One menu surface per screen; the controller decides which one is open.
    Variants {
        id: menuWindows
        model: Quickshell.screens
        delegate: PunchiMenuWindow {
            property var modelData
            screen: modelData
            settings: shellSettings
            menuController: menuController
            applications: dockServices.catalog
            distribution: dockServices.distribution
        }
    }
    Variants {
        id: dockWindows
        model: Quickshell.screens
        delegate: PunchiDock {
            property var modelData
            services: dockServices
            screenPolicy: screenPolicy
            desktopPolicy: desktopPolicy
            screen: modelData
            configuring: settingsWindow.visible
            onSettingsRequested: settingsWindow.open()
            onMenuRequested: function(screenKey) { menuController.toggle(screenKey) }
        }
    }
    PunchiDockIpc {
        docks: dockWindows.instances
        menuController: menuController
        settings: shellSettings
        primaryScreenName: screenPolicy.primaryScreenName
        onSettingsRequested: settingsWindow.open()
    }
    PunchiSettingsStore { settings: shellSettings }
    PunchiAutostartService { id: autostart }
    PunchiLicenseDocument { id: licenseDocument }
    PunchiSettingsWindow {
        id: settingsWindow
        settings: shellSettings
        applicationCatalog: dockServices.applicationCatalog
        autostart: autostart
        license: licenseDocument
        recentApplications: dockServices.recentApplications
        updates: dockServices.updateNotice
        screens: Quickshell.screens
        primaryScreenName: screenInfo.primaryName
        runningApplications: dockServices.runningApplications
    }
}
