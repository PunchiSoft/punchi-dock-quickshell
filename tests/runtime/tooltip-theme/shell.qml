// SPDX-License-Identifier: GPL-3.0-or-later
//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import org.kde.kirigami as Kirigami
import "../../../components"
import "../../../modules/dock"

ShellRoot {
    id: probe
    property int frame: 0
    property bool capturing: false
    property var originalSurface: null
    // Popup exposes generic Items; inspect its concrete instances at capture
    // time without casting style- or Quickshell-generated QML subclasses.
    function inspectItem(item: var): var { return item }
    function menuSurface(): var {
        for (const child of menu.children)
            if (child.objectName === "dockContextSurface") return child
        return null
    }
    Window {
        visible: true
        width: 600
        height: 200
        Item {
            id: host
            anchors.fill: parent
            PunchiDockTooltip {
                id: tooltip
                parent: host
                text: "Owned application"
                x: 40; y: 40
                delay: 0
                palette.toolTipBase: "#ffee00"
                palette.toolTipText: "#990099"
                palette.mid: "#abcdef"
                Component.onCompleted: open()
            }
            PunchiDockContextContent { id: menu; x: 240; y: 40 }
        }
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (!tooltip.opened || probe.capturing) return
            const surface = probe.inspectItem(tooltip.background)
            const label = probe.inspectItem(tooltip.contentItem)
            const menuSurface = probe.menuSurface()
            if (!menuSurface) {
                console.error("PUNCHI_TOOLTIP_FAILED menu surface"); Qt.quit(); return
            }
            if (!surface || !label || typeof surface.tailHeight !== "number"
                || label.color === undefined || label.font === undefined) {
                console.error("PUNCHI_TOOLTIP_FAILED production content types"); Qt.quit(); return
            }
            if (!probe.originalSurface) probe.originalSurface = surface
            if (probe.originalSurface !== surface || !surface.tailHeight
                || tooltip.focus || tooltip.x !== 40 || tooltip.y !== 40) {
                console.error("PUNCHI_TOOLTIP_FAILED geometry or lifetime"); Qt.quit(); return
            }
            probe.capturing = true
            const frame = ++probe.frame
            surface.grabToImage(function(result) {
                if (!result.saveToFile(Quickshell.env("PUNCHI_TOOLTIP_IMAGES") + "/" + frame + ".png")) {
                    console.error("PUNCHI_TOOLTIP_FAILED capture"); Qt.quit(); return
                }
                console.warn("PUNCHI_TOOLTIP_FRAME", JSON.stringify({
                    frame: frame, background: surface.fillColor.toString(),
                    text: label.color.toString(), border: surface.strokeColor.toString(),
                    font: label.font.family, tail: surface.tailHeight,
                    menuBackground: menuSurface.fillColor.toString(),
                    menuBorder: menuSurface.strokeColor.toString(),
                    menuText: menu.Kirigami.Theme.textColor.toString()
                }))
                probe.capturing = false
            })
        }
    }
}
