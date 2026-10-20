// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
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
    Dock { id: dock; configuring: settingsWindow.visible; onSettingsRequested: settingsWindow.open() }
    SettingsStore { settings: dock.preferences }
    AutostartService { id: autostart }
    LicenseDocument { id: licenseDocument }
    SettingsWindow {
        id: settingsWindow
        settings: dock.preferences
        applicationCatalog: dock.applicationCatalog
        autostart: autostart
        license: licenseDocument
        recentApplications: dock.recentApplications
    }
}
