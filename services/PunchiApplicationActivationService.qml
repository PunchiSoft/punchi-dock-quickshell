// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root
    required property var entries
    required property var launcher
    property var newWindowLauncher: launcher
    property var windowState: null
    property var pending: ({})
    readonly property PunchiApplicationStartupGuard startup: PunchiApplicationStartupGuard { windowState: root.windowState }
    signal activationDispatched(string appId)
    signal activationRejected(string appId)

    function desktopIdFor(appId: string): string {
        for (let row = 0; row < entries.count; ++row) {
            const entry = entries.get(row)
            if (entry.appId === appId) return entry.desktopId || ""
        }
        return ""
    }
    function activate(appId: string): bool {
        const desktopId = desktopIdFor(appId)
        if (!desktopId) { activationRejected(appId); return false }
        // Unconfigured development hosts retain their launch-only entry point.
        if (!windowState || !windowState.configured) return launcher.launch(appId)
        startup.observe()
        if (startup.holds(desktopId)) return true
        for (const request of Object.values(pending))
            if (!request.newInstance && startup.key(request.desktopId) === startup.key(desktopId)) return true
        const requestId = windowState.windowActivation.requestActivate(desktopId)
        if (requestId <= 0) { activationRejected(appId); return false }
        pending[requestId] = {appId, desktopId, newInstance: false}
        return true
    }
    function newWindow(appId: string): bool {
        const desktopId = desktopIdFor(appId)
        if (!desktopId) { activationRejected(appId); return false }
        if (!windowState || !windowState.configured) return newWindowLauncher.launch(appId)
        const requestId = windowState.windowActivation.requestNewInstance(desktopId)
        if (requestId <= 0) { activationRejected(appId); return false }
        pending[requestId] = {appId, desktopId, newInstance: true}
        return true
    }
    readonly property Connections launchCompletion: Connections {
        target: root.launcher
        ignoreUnknownSignals: true
        function onLaunchCompleted(desktopId, success, error) {
            if (!success) root.startup.release(desktopId)
        }
    }
    readonly property Connections completion: Connections {
        target: root.windowState ? root.windowState.windowActivation : null
        function onFinished(requestId, desktopId, status) {
            const intent = root.pending[requestId]
            if (!intent) return
            delete root.pending[requestId]
            const expected = intent.desktopId.endsWith(".desktop")
                ? intent.desktopId.slice(0, -8) : intent.desktopId
            if (desktopId !== expected) { root.activationRejected(intent.appId); return }
            if (status === "activated" || status === "minimized" || status === "starting" || status === "new-instance")
                root.activationDispatched(intent.appId)
            else if (status === "not-found" && root.desktopIdFor(intent.appId) === intent.desktopId) {
                if (intent.newInstance) root.newWindowLauncher.launch(intent.appId)
                else if (root.startup.reserve(intent.desktopId) && !root.launcher.launch(intent.appId))
                    root.startup.release(intent.desktopId)
            }
            else root.activationRejected(intent.appId)
        }
    }
}
