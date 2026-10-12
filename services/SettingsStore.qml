// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Quickshell.Io
import "../config"
QtObject {
    id: root
    required property ShellSettings settings
    property bool ready: false
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config") + "/punchi-shell.json"
    readonly property FileView file: FileView {
        path: root.path
        preload: false
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: console.warn("Punchi Shell: settings save failed")
    }
    readonly property PersistentProperties session: PersistentProperties {
        id: sessionState
        reloadableId: "punchi-shell-settings"
        property string snapshot: ""
        onLoaded: root.initialize(sessionState.snapshot)
    }
    function save(): void {
        if (!ready) return
        sessionState.snapshot = JSON.stringify(settings.snapshot(), null, 2)
        file.setText(sessionState.snapshot)
    }
    readonly property Connections changes: Connections {
        target: root.settings
        function onPanelModeChanged() { root.save() }
        function onSizePercentChanged() { root.save() }
        function onMaximumIconScaleChanged() { root.save() }
        function onMagnificationEnabledChanged() { root.save() }
        function onReducedMotionChanged() { root.save() }
        function onBounceEnabledChanged() { root.save() }
        function onPinnedIdsChanged() { root.save() }
    }
    function initialize(previous: string): void {
        ready = false
        const text = previous || file.text()
        if (text.length > 0 && text.length <= 16384) {
            try { settings.restore(JSON.parse(text)) }
            catch (error) { console.warn("Punchi Shell: invalid settings JSON") }
        }
        // Startup overrides apply once, not on each source reload.
        if (previous.length === 0) {
            const mode = Quickshell.env("PUNCHI_DOCK_MODE")
            if (["overlay", "reserve", "desktop", "autohide"].indexOf(mode) >= 0)
                settings.panelMode = mode
        }
        sessionState.snapshot = JSON.stringify(settings.snapshot(), null, 2)
        ready = true
    }
}
