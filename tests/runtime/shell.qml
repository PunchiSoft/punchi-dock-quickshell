// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../config"
import "../../modules/dock"

ShellRoot {
    id: root
    property int stage: 0
    property int renderedFrames: 0

    ShellSettings { id: settings }
    DockServices { id: services; settings: settings }
    Dock {
        id: dock
        services: services
        onWindowConnected: console.warn("PUNCHI_WINDOW_CONNECTED")
    }

    Connections {
        target: dock.contentItem.Window.window
        function onFrameSwapped() { root.renderedFrames += 1 }
    }

    // Bounded test observations, not an animation engine.
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (root.stage === 0) {
                if (!dock.backingWindowVisible || root.renderedFrames < 1
                        || dock.width <= 0 || dock.height <= 0 || !dock.screen) {
                    console.error("PUNCHI_SESSION_FAILED_INITIAL_SURFACE")
                    Qt.quit()
                    return
                }
                console.warn("PUNCHI_FRAME_RENDERED", dock.width, dock.height)
                dock.requestedVisible = false
            } else if (root.stage === 1) {
                if (dock.backingWindowVisible) {
                    console.error("PUNCHI_SESSION_FAILED_HIDE")
                    Qt.quit()
                    return
                }
                dock.requestedVisible = true
                root.renderedFrames = 0
            } else {
                if (!dock.backingWindowVisible || root.renderedFrames < 1) {
                    console.error("PUNCHI_SESSION_FAILED_REOPEN")
                } else {
                    console.warn("PUNCHI_SESSION_PASS")
                }
                Qt.quit()
            }
            root.stage += 1
        }
    }
}
