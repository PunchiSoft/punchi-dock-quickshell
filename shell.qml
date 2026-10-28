// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import "config"
import Punchi.Kde as Native
import "modules/dock"
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
    ShellSettings {
        id: shellSettings
        panelMode: Quickshell.env("PUNCHI_DOCK_MODE") || "overlay"
    }
    // One catalog, window backend and update tracker serve every dock window.
    DockServices { id: dockServices; settings: shellSettings }
    Native.ScreenInfo { id: screenInfo }
    ScreenPolicy {
        id: screenPolicy
        settings: shellSettings
        connectedScreens: Quickshell.screens
        primaryScreenName: screenInfo.primaryName
    }
    VirtualDesktopPolicy {
        id: desktopPolicy
        settings: shellSettings
        runningApplications: dockServices.runningApplications
    }
    Variants {
        id: dockWindows
        model: Quickshell.screens
        delegate: Dock {
            property var modelData
            services: dockServices
            screenPolicy: screenPolicy
            desktopPolicy: desktopPolicy
            screen: modelData
            configuring: settingsWindow.visible
            onSettingsRequested: settingsWindow.open()
        }
    }
    DockIpc {
        docks: dockWindows.instances
        settings: shellSettings
        primaryScreenName: screenPolicy.primaryScreenName
        onSettingsRequested: settingsWindow.open()
    }
    SettingsStore { settings: shellSettings }
    AutostartService { id: autostart }
    LicenseDocument { id: licenseDocument }
    SettingsWindow {
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
