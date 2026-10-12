// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound

import Quickshell
import "modules/dock"
import "modules/settings"
import "services"

ShellRoot {
    Dock { id: dock; configuring: settingsWindow.visible; onSettingsRequested: settingsWindow.open() }
    SettingsStore { settings: dock.preferences }
    SettingsWindow { id: settingsWindow; settings: dock.preferences; applicationCatalog: dock.applicationCatalog }
}
