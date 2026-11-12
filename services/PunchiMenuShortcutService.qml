// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Punchi.Kde as Native
import "../config"
import "../config/PunchiScreenSelection.js" as PunchiScreenSelection

// Single owner of the configurable global menu shortcut. The native controller
// owns KGlobalAccel; this service resolves the screen and toggles the menu.
// A shortcut has no dock anchor, so the pointer screen is used only when the
// screen policy allows it, with last-used, selected, primary and first-active
// fallbacks.
QtObject {
    id: root

    required property PunchiShellSettings settings
    required property PunchiMenuController menuController
    required property PunchiScreenPolicy screenPolicy
    property var screenInfo: null
    // The settings store writes only after it has loaded the profile. Waiting
    // for it keeps a normalized shortcut from being corrected only in memory.
    property bool settingsReady: false

    readonly property bool registered: shortcut.registered
    readonly property string activeShortcut: shortcut.activeShortcut

    signal registrationFailed(string requestedShortcut)

    readonly property Native.MenuShortcutController shortcut: Native.MenuShortcutController {
        configuredShortcut: root.settings ? root.settings.menuShortcut : ""
        onActivated: root.toggleMenu()
        onShortcutRegistrationFailed: function(requestedShortcut) {
            // Keep the setting editable and the shell alive; the settings page
            // can surface the failure later without pretending it registered.
            console.warn("Punchi Dock Quickshell: menu shortcut registration failed:",
                requestedShortcut)
            root.registrationFailed(requestedShortcut)
        }
    }
    readonly property Connections normalizedShortcut: Connections {
        target: root.shortcut
        function onConfiguredShortcutChanged() {
            root.reconcileShortcut()
        }
    }
    onSettingsReadyChanged: root.reconcileShortcut()

    function reconcileShortcut(): void {
        // A profile may carry a valid-looking but non-canonical sequence. Write
        // the controller's normalized form back so the setting and the
        // registered shortcut never disagree. The store must be ready or the
        // correction would not reach the file.
        if (!root.settingsReady || !root.settings) return
        if (root.settings.menuShortcut !== root.shortcut.configuredShortcut)
            root.settings.menuShortcut = root.shortcut.configuredShortcut
    }

    function preferredScreenKey(): string {
        if (!root.screenPolicy) return ""
        const activeName = root.screenInfo ? root.screenInfo.activeName() : ""
        return PunchiScreenSelection.preferredScreenKey(
            root.screenPolicy.connectedScreens,
            root.settings ? root.settings.screenMode : "all",
            root.settings ? (root.settings.selectedScreens || []) : [],
            root.screenPolicy.primaryScreenName,
            activeName,
            root.menuController ? root.menuController.lastScreenKey : "")
    }

    function toggleMenu(): bool {
        if (!root.menuController) return false
        if (root.menuController.openScreenKey.length > 0)
            return root.menuController.close()
        // Do not stack a new surface on one that is still fading out. The next
        // press opens once the compositor has unmapped it.
        if (root.menuController.mappedScreenKey.length > 0) return false
        const target = root.preferredScreenKey()
        return target.length > 0 ? root.menuController.open(target) : false
    }
}
