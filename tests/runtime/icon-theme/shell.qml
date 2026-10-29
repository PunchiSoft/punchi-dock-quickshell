// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../../components"
import "../../../modules/dock"
import "../../../modules/settings"

ShellRoot {
    id: probe
    property int frame: 0
    property bool capturing: false
    function iconIn(item: var, name: string): var {
        if (item.source !== undefined && item.source === name) return item
        const children = item.children || []
        for (let i = 0; i < children.length; ++i) {
            const found = iconIn(children[i], name)
            if (found) return found
        }
        return null
    }
    Window {
        visible: true
        width: 960
        height: 500
        Item {
            id: surface
            anchors.fill: parent
            PunchiDockTile { id: app; title: "Owned app"; iconName: "owned-app"; x: 40; y: 40; tooltipsEnabled: false; targetIconScale: 1.25 }
            PunchiDockTile { id: empty; title: "Owned empty"; iconName: "user-trash"; x: 140; y: 40; tooltipsEnabled: false }
            PunchiDockTile { id: full; title: "Owned full"; iconName: "user-trash-full"; x: 240; y: 40; tooltipsEnabled: false }
            PunchiDockContextAction { id: action; text: "Owned action"; icon.name: "owned-app"; x: 40; y: 140; width: 240 }
            PunchiApplicationListRow { id: row; text: "Owned row"; iconName: "owned-app"; x: 40; y: 240; width: 240 }
            PunchiTrashConfirmationContent { id: confirmation; questionText: "Owned question"; warningText: "Owned warning"; x: 400; y: 40 }
        }
    }
    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (probe.capturing) return
            const icons = [probe.iconIn(app, "owned-app"), probe.iconIn(empty, "user-trash"),
                probe.iconIn(full, "user-trash-full"), probe.iconIn(action, "owned-app"),
                probe.iconIn(row, "owned-app"), probe.iconIn(confirmation, "user-trash-full")]
            if (icons.some(icon => !icon)) {
                console.error("PUNCHI_ICONS_FAILED missing production icon"); Qt.quit(); return
            }
            probe.capturing = true
            const frame = ++probe.frame
            let pending = icons.length
            for (let i = 0; i < icons.length; ++i) {
                icons[i].grabToImage(result => {
                    const file = Quickshell.env("PUNCHI_ICON_IMAGES") + "/" + frame + "-" + i + ".png"
                    if (!result.saveToFile(file)) {
                        console.error("PUNCHI_ICONS_FAILED capture"); Qt.quit(); return
                    }
                    if (--pending === 0) {
                        if (app.iconName !== "owned-app" || app.targetIconScale !== 1.25 || app.activeFocus) {
                            console.error("PUNCHI_ICONS_FAILED item state changed"); Qt.quit(); return
                        }
                        console.warn("PUNCHI_ICON_FRAME", frame)
                        probe.capturing = false
                    }
                })
            }
        }
    }
}
