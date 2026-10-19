// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    objectName: "autostartService"

    readonly property string marker: "X-Punchi-Dock-Quickshell-Owned=true"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config"
    readonly property string directory: configHome + "/autostart"
    readonly property string path: directory + "/punchi-dock-quickshell.desktop"
    readonly property string launcherPath: Quickshell.shellDir + "/scripts-user/launcher.sh"
    readonly property string iconPath: Quickshell.shellDir
        + "/assets/icons/punchi-dock-quickshell.svg"

    property bool active: false
    property bool draftEnabled: false
    property bool creatingDirectory: false
    property bool removing: false
    property bool present: false
    property string error: ""
    property string currentText: ""

    readonly property bool owned: currentText.indexOf(marker) >= 0
    readonly property bool foreign: present && !owned
    readonly property bool enabled: owned
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
        currentText = file.text()
    }

    function execQuote(value: string): string {
        return "\"" + String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/`/g, "\\`")
            .replace(/\$/g, "\\$")
            .replace(/%/g, "%%") + "\""
    }

    function contents(): string {
        return [
            "[Desktop Entry]",
            "Type=Application",
            "Name=Punchi Dock Quickshell",
            "Exec=" + execQuote(launcherPath) + " start",
            "Icon=" + iconPath,
            "Terminal=false",
            "OnlyShowIn=KDE;",
            "X-KDE-autostart-phase=2",
            marker,
            ""
        ].join("\n")
    }

    readonly property FileView file: FileView {
        path: root.path
        preload: true
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.present = true
            root.refresh()
        }
        onFileChanged: {
            root.refresh()
            if (!root.available) root.draftEnabled = root.enabled
        }
        onTextChanged: root.refresh()
        onLoadFailed: {
            root.present = false
            root.currentText = ""
        }
        onSaved: {
            root.present = true
            root.refresh()
            root.draftEnabled = root.enabled
            root.error = ""
        }
        onSaveFailed: {
            root.refresh()
            root.present = root.enabled
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
            root.file.reload()
            root.refresh()
            if (!root.enabled) root.present = false
            root.draftEnabled = root.enabled
            root.error = root.enabled ? "remove" : ""
        }
    }

    Component.onCompleted: refresh()
}
