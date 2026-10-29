// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import "../../../services"
import "../../../modules/dock"

TestCase {
    id: test
    name: "KdeApplicationMedia"
    when: windowShown
    PunchiApplicationMediaService { id: mediaSession; desktopId: "punchi-owned-media.desktop" }
    PunchiApplicationMediaService { id: unknown; desktopId: "unrelated-app.desktop" }
    PunchiApplicationMediaService { id: other; desktopId: "punchi-other-media.desktop" }
    Window {
        id: viewport
        visible: true
        width: 600
        height: 600
        Item { id: anchor; x: 280; y: 550; width: 40; height: 40 }
        PunchiDockContextPopup {
            id: menu
            hostWindow: viewport
            media: mediaSession
            onMediaCommandRequested: function(command) { test.verify(mediaSession.dispatch(command)) }
        }
    }
    function init() { failOnWarning(/.*/) }
    function test_nativeDiscoveryReactiveCapabilitiesAndScopedCommands() {
        viewport.requestActivate()
        tryCompare(viewport, "active", true)
        tryCompare(mediaSession, "available", true)
        tryCompare(other, "available", true)
        compare(unknown.available, false)
        verify(!unknown.dispatch("play-pause"))
        compare(mediaSession.title, "Owned track")
        compare(mediaSession.artist, "Owned artist")
        compare(mediaSession.playing, true)
        compare(mediaSession.canStop, true)
        menu.openForItem(anchor, "Owned player")
        tryCompare(menu, "opened", true)
        const pause = findChild(menu.mainItem, "mediaPlayPauseAction")
        compare(pause.text, "Pause")
        mouseClick(pause, pause.width / 2, pause.height / 2)
        tryCompare(menu, "visible", false)
        tryCompare(mediaSession, "playing", false)
        verify(mediaSession.dispatch("previous"))
        tryCompare(mediaSession, "title", "Previous owned track")
        verify(mediaSession.dispatch("next"))
        // The fixture changes CanGoNext after the actual Next DBus command.
        tryCompare(mediaSession, "canNext", false)
        verify(!mediaSession.dispatch("next"))
        verify(!mediaSession.dispatch("quit"))
        menu.openForItem(anchor, "Owned player")
        tryCompare(menu, "opened", true)
        compare(findChild(menu.mainItem, "mediaNextAction").enabled, false)
        compare(pause.text, "Play")
        pause.forceActiveFocus(Qt.TabFocusReason)
        tryCompare(pause, "activeFocus", true)
        keyClick(Qt.Key_Return)
        tryCompare(menu, "visible", false)
        tryCompare(mediaSession, "playing", true)
        verify(mediaSession.dispatch("stop"))
        tryCompare(mediaSession, "canStop", false)
        verify(!mediaSession.dispatch("stop"))
        // Stop retires the owned player after its stopped state reaches the UI.
        menu.openForItem(anchor, "Owned player")
        tryCompare(menu, "opened", true)
        tryCompare(mediaSession, "available", false)
        compare(findChild(menu.mainItem, "dockContextMedia").visible, false)
        verify(!mediaSession.dispatch("play-pause"))
        wait(100)
        verify(other.available, "other="+other.desktopId+", entry="+other.adapter.desktopEntry+", rows="+other.adapter.players.rowCount()+", candidate="+other.adapter.players.playerForLauncherUrl("applications:punchi-other-media.desktop",0)+", revision="+other.adapter.revision)
        compare(unknown.available, false)
        mediaSession.desktopId = "../punchi-other-media"
        compare(mediaSession.available, false)
        menu.close()
    }
}
