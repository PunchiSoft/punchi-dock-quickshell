// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root

    required property var entries
    required property var adapter
    signal launchDispatched(string appId)
    signal launchRejected(string appId)
    signal launchCompleted(string desktopId, bool success, string error)
    readonly property Connections completion: Connections {
        target: root.adapter
        ignoreUnknownSignals: true
        function onLaunchFinished(desktopId, success, error) {
            root.launchCompleted(desktopId, success, error)
        }
    }

    function launch(appId: string): bool {
        for (let i = 0; i < root.entries.count; ++i) {
            const entry = root.entries.get(i)
            if (entry.appId !== appId) continue
            if (entry.desktopId && root.adapter.launch(entry.desktopId)) {
                root.launchDispatched(appId)
                return true
            }
            root.launchRejected(appId)
            return false
        }
        root.launchRejected(appId)
        return false
    }
    function actions(appId: string): list<var> {
        for (let i = 0; i < root.entries.count; ++i) {
            const entry = root.entries.get(i)
            if (entry.appId === appId) return root.adapter.actions(entry.desktopId)
        }
        return []
    }
    function launchAction(appId: string, actionId: string): bool {
        for (let i = 0; i < root.entries.count; ++i) {
            const entry = root.entries.get(i)
            if (entry.appId !== appId) continue
            if (root.adapter.launchAction(entry.desktopId, actionId)) {
                root.launchDispatched(appId)
                return true
            }
            break
        }
        root.launchRejected(appId)
        return false
    }
}
