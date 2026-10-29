// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../../config/PunchiPanelModes.js" as PunchiPanelModes

// Single command surface for every dock window. A second IpcHandler with the
// same target would compete with this one, so per-screen commands resolve an
// instance from the dock list instead of registering another handler.
Scope {
    id: root
    required property var docks
    required property PunchiShellSettings settings
    // Preferred target for the legacy commands. Empty until the screen policy
    // reports the system primary screen.
    property string primaryScreenName: ""
    signal settingsRequested()

    readonly property var referenceDock: {
        if (!root.docks || root.docks.length === 0) return null
        for (const candidate of root.docks) {
            if (candidate && candidate.screen && candidate.screen.name === root.primaryScreenName)
                return candidate
        }
        return root.docks[0]
    }
    function dockFor(screenKey: string): var {
        for (const candidate of root.docks || []) {
            if (candidate && candidate.screen && candidate.screen.name === screenKey)
                return candidate
        }
        return null
    }
    function screenKey(dock): string {
        return dock && dock.screen ? dock.screen.name : ""
    }
    IpcHandler {
        target: "dock"
        function setMode(mode: string): bool {
            if (!PunchiPanelModes.accepts(mode)) return false
            root.settings.panelMode = mode
            return true
        }
        function revealDock(): bool {
            const dock = root.referenceDock
            return dock ? dock.reveal() : false
        }
        function focusDock(): bool {
            const dock = root.referenceDock
            return dock ? dock.focus() : false
        }
        function openSettings(): bool {
            root.settingsRequested()
            return true
        }
        function snapshot(): string {
            const dock = root.referenceDock
            return dock ? dock.snapshot() : "{}"
        }
        function screenKeys(): string {
            return JSON.stringify((root.docks || []).map(dock => root.screenKey(dock)))
        }
        function snapshotFor(screenKey: string): string {
            const dock = root.dockFor(screenKey)
            return dock ? dock.snapshot() : "{}"
        }
        function revealFor(screenKey: string): bool {
            const dock = root.dockFor(screenKey)
            return dock ? dock.reveal() : false
        }
        function focusFor(screenKey: string): bool {
            const dock = root.dockFor(screenKey)
            return dock ? dock.focus() : false
        }
    }
}
