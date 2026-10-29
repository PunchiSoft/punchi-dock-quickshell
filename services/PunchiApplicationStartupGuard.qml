// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root
    property var windowState: null
    // Lifecycle fallback, not a motion duration or a persisted preference.
    property int timeout: 30000
    property var deadlines: Object.create(null)
    function key(desktopId: string): string {
        return desktopId.endsWith(".desktop") ? desktopId.slice(0, -8) : desktopId
    }
    function holds(desktopId: string): bool {
        const id = key(desktopId)
        if (!deadlines[id]) return false
        if (deadlines[id] > Date.now()) return true
        release(id)
        return false
    }
    function reserve(desktopId: string): bool {
        const id = key(desktopId)
        if (!id || holds(id) || Object.keys(deadlines).length >= 64) return false
        deadlines[id] = Date.now() + Math.max(1, timeout)
        schedule()
        return true
    }
    function release(desktopId: string): void { delete deadlines[key(desktopId)]; schedule() }
    function schedule(): void {
        expiry.stop()
        let earliest = Infinity
        for (const id of Object.keys(deadlines)) earliest = Math.min(earliest, deadlines[id])
        if (Number.isFinite(earliest)) {
            expiry.interval = Math.max(1, earliest - Date.now())
            expiry.start()
        }
    }
    function observe(): void {
        if (!windowState || typeof windowState.isRunningDesktop !== "function") return
        for (const id of Object.keys(deadlines))
            if (windowState.isRunningDesktop(id)) delete deadlines[id]
        schedule()
    }
    readonly property Timer expiry: Timer {
        onTriggered: {
            const now = Date.now()
            for (const id of Object.keys(root.deadlines))
                if (root.deadlines[id] <= now) delete root.deadlines[id]
            root.schedule()
        }
    }
    readonly property Connections windows: Connections {
        target: root.windowState
        ignoreUnknownSignals: true
        function onRevisionChanged() { root.observe() }
    }
}
