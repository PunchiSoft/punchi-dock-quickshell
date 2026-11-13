// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Quickshell.Io
import Punchi.Kde as Native
import "PunchiAutostartEntry.js" as PunchiAutostartEntry

QtObject {
    id: root
    objectName: "autostartService"

    readonly property string marker: "X-Punchi-Dock-Quickshell-Owned=true"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config"
    // A trial run exports an absolute profile directory, so an entry created
    // there is never loaded by the session and disappears with the profile.
    readonly property string profileDir: {
        const dir = Quickshell.env("PUNCHI_PROFILE_DIR")
        return dir && dir.charAt(0) === "/" ? dir : ""
    }
    readonly property string directory: profileDir.length > 0
        ? profileDir + "/autostart"
        : configHome + "/autostart"
    readonly property string path: directory + "/punchi-dock-quickshell.desktop"
    readonly property string launcherPath: Quickshell.shellDir + "/scripts-user/launcher.sh"
    readonly property string iconPath: Quickshell.shellDir
        + "/assets/icons/punchi-dock-quickshell.svg"
    readonly property string launcherExec: "Exec=" + PunchiAutostartEntry.execQuote(launcherPath) + " start"
    // The entry is a small desktop file. The bounded reader rejects a FIFO, a
    // directory, a device and any file above this limit before opening it, so a
    // foreign path cannot stall the GUI thread before settings load.
    readonly property int maximumBytes: 16 * 1024
    readonly property var reader: Native.ProfileFile {}

    property bool active: false
    property bool draftEnabled: false
    property bool creatingDirectory: false
    property bool removing: false
    property bool present: false
    property string error: ""
    property string currentText: ""

    // Only a file that carries the exact marker line and our exact launcher
    // command is ours. A substring match would let a foreign entry that merely
    // mentions the marker be overwritten or removed.
    readonly property bool owned: hasLine(currentText, marker)
        && hasLine(currentText, launcherExec)
    readonly property bool foreign: present && !owned
    readonly property bool enabled: owned
    // A trial profile is never loaded by the session, so its switch stays off.
    readonly property bool trial: profileDir.length > 0
    // A file created by another tool at our exact path is never overwritten or
    // removed. The switch is shown disabled instead.
    readonly property bool available: !foreign
    readonly property bool dirty: active && draftEnabled !== enabled

    function begin(): void {
        error = ""
        active = true
        draftEnabled = enabled
    }

    function cancel(): void {
        active = false
        draftEnabled = enabled
        error = ""
    }

    function apply(): bool {
        if (!active) return false
        if (draftEnabled === enabled) {
            error = ""
            return true
        }
        if (draftEnabled && !available) {
            error = "foreign"
            return false
        }
        if (draftEnabled) {
            creatingDirectory = true
            directoryCreator.running = true
            return true
        }
        if (!owned) {
            error = "foreign"
            return false
        }
        removing = true
        remover.running = true
        return true
    }

    function refresh(): void {
        if (reader.isSymlink(path)) {
            present = true
            currentText = ""
            return
        }
        const result = reader.readPath(path, maximumBytes)
        if (result && result.ok) {
            present = true
            currentText = result.text
            return
        }
        const reason = result && result.error ? result.error : "read-failed"
        // A missing entry is the normal first start. Every other outcome leaves
        // the existing path in place and marks it foreign, so it is never
        // overwritten or removed.
        present = reason !== "missing"
        currentText = ""
    }

    function hasLine(text: string, expected: string): bool {
        return text.split(/\r?\n/).indexOf(expected) >= 0
    }

    function contents(): string {
        return [
            "[Desktop Entry]",
            "Type=Application",
            "Name=Punchi Dock Quickshell",
            launcherExec,
            "Icon=" + PunchiAutostartEntry.valueQuote(iconPath),
            "Terminal=false",
            "OnlyShowIn=KDE;",
            "X-KDE-autostart-phase=2",
            marker,
            ""
        ].join("\n")
    }

    readonly property FileView file: FileView {
        path: root.path
        // Reading goes through the bounded reader in refresh(); FileView only
        // watches for external changes and writes atomically.
        preload: false
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: {
            root.refresh()
            if (!root.available) root.draftEnabled = root.enabled
        }
        onSaved: {
            root.refresh()
            root.draftEnabled = root.enabled
            root.error = ""
        }
        onSaveFailed: {
            root.refresh()
            root.draftEnabled = root.enabled
            root.error = "save"
        }
    }

    readonly property Process directoryCreator: Process {
        command: ["mkdir", "-p", root.directory]
        onRunningChanged: {
            if (!root.creatingDirectory || running) return
            root.creatingDirectory = false
            root.file.setText(root.contents())
        }
    }

    readonly property Process remover: Process {
        command: ["rm", "-f", root.path]
        onRunningChanged: {
            if (!root.removing || running) return
            root.removing = false
            root.refresh()
            if (!root.enabled) root.present = false
            root.draftEnabled = root.enabled
            root.error = root.enabled ? "remove" : ""
        }
    }

    Component.onCompleted: refresh()
}
