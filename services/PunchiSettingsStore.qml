// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
import "../config"
import "../config/PunchiPanelModes.js" as PunchiPanelModes
import "../config/PunchiProfileDocument.js" as PunchiProfileDocument
// Scope (a non-visual ReloadPropagator) instead of QtObject: the persistent
// session must be a real child. A PersistentProperties held as a property value
// is not matched by Quickshell's reloader, so its `loaded` signal fires with no
// restored state and re-applying the start mode after every reload clobbers live
// changes. `Singleton` also groups children but Qt rejects it outside its own
// root component.
Scope {
    id: root
    required property PunchiShellSettings settings
    property bool ready: false
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config"
    // A trial run exports an absolute profile directory so it never reads or
    // writes the profile an installed copy owns.
    readonly property string profileDir: {
        const dir = Quickshell.env("PUNCHI_PROFILE_DIR")
        return dir && dir.charAt(0) === "/" ? dir : ""
    }
    readonly property string path: profileDir.length > 0
        ? profileDir + "/punchi-dock-quickshell.json"
        : configHome + "/punchi-dock-quickshell.json"
    readonly property string legacyPath: profileDir.length > 0
        ? profileDir + "/punchi-shell.json"
        : configHome + "/punchi-shell.json"
    readonly property FileView file: FileView {
        path: root.path
        preload: false
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: console.warn("Punchi Dock Quickshell: settings save failed")
    }
    // The owned settings file goes through the same bounded, regular-file-only
    // reader as imported profiles; FileView remains the atomic writer.
    readonly property var reader: Native.ProfileFile {}
    PersistentProperties {
        id: sessionState
        reloadableId: "punchi-shell-settings"
        property string snapshot: ""
        onLoaded: root.initialize(sessionState.snapshot)
    }
    function save(): void {
        if (!ready || settings.bulkChange) return
        const snapshot = JSON.stringify(settings.snapshot(), null, 2)
        // Never replace a readable profile with one the bounded loader would
        // reject on the next start. The previous file stays intact.
        if (snapshot.length > PunchiProfileDocument.maximumBytes) {
            console.warn("Punchi Dock Quickshell: settings profile exceeds the storage limit")
            return
        }
        sessionState.snapshot = snapshot
        file.setText(snapshot)
    }
    readonly property Connections changes: Connections {
        target: root.settings
        function onDownloadsViewChanged() { root.save() }
        function onDockEdgeChanged() { root.save() }
        function onPanelModeChanged() { root.save() }
        function onScreenModeChanged() { root.save() }
        function onSelectedScreensChanged() { root.save() }
        function onDesktopModeChanged() { root.save() }
        function onSelectedDesktopsChanged() { root.save() }
        function onActivityModeChanged() { root.save() }
        function onSelectedActivitiesChanged() { root.save() }
        function onRunningMarkersFollowDesktopChanged() { root.save() }
        function onAvoidInnerEdgeAutoHideChanged() { root.save() }
        function onSizePercentChanged() { root.save() }
        function onMaximumIconScaleChanged() { root.save() }
        function onMagnificationEnabledChanged() { root.save() }
        function onReducedMotionChanged() { root.save() }
        function onBounceEnabledChanged() { root.save() }
        function onRecentApplicationsEnabledChanged() { root.save() }
        function onRecentApplicationsCountChanged() { root.save() }
        function onRecentApplicationsPresentationChanged() { root.save() }
        function onRecentApplicationsContainerLayoutChanged() { root.save() }
        function onUpdateBadgeEnabledChanged() { root.save() }
        function onPinnedIdsChanged() { root.save() }
        function onIconOverridesChanged() { root.save() }
        function onContainersChanged() { root.save() }
        function onPopupScaleChanged() { root.save() }
        function onPopupIconSizeChanged() { root.save() }
        function onPopupHeightPercentChanged() { root.save() }
        function onProfileApplied() { root.save() }
    }
    function readStored(path: string): var {
        const result = reader.readPath(path, PunchiProfileDocument.maximumBytes)
        if (result && result.ok) return {ok: true, text: result.text, error: ""}
        const error = result && result.error ? result.error : "read-failed"
        // A missing file is the normal first start; every other outcome keeps
        // the defaults and must not fall back to the legacy profile.
        if (error !== "missing")
            console.warn("Punchi Dock Quickshell: settings read failed:", error)
        return {ok: false, text: "", error: error}
    }
    function initialize(previous: string): void {
        ready = false
        let text = previous
        let migrateLegacy = false
        if (text.length === 0) {
            const current = readStored(root.path)
            if (current.ok) text = current.text
            const legacyAllowed = current.ok
                ? text.length === 0 : current.error === "missing"
            if (legacyAllowed) {
                const legacy = readStored(root.legacyPath)
                if (legacy.ok && legacy.text.length > 0) {
                    text = legacy.text
                    migrateLegacy = true
                }
            }
        }
        if (text.length === 0) settings.reset()
        if (text.length > 0 && text.length <= PunchiProfileDocument.maximumBytes) {
            try {
                const restored = settings.restore(JSON.parse(text))
                if (restored && migrateLegacy) file.setText(text)
            } catch (error) { console.warn("Punchi Dock Quickshell: invalid settings JSON") }
        }
        // Startup overrides apply once, not on each source reload. The session
        // object is now a real child, so it is restored before this signal.
        if (previous.length === 0) {
            const mode = Quickshell.env("PUNCHI_DOCK_MODE")
            if (PunchiPanelModes.accepts(mode))
                settings.panelMode = PunchiPanelModes.normalize(mode)
        }
        sessionState.snapshot = JSON.stringify(settings.snapshot(), null, 2)
        ready = true
    }
}
