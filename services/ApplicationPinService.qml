// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../adapters/kde"
import "../config/LauncherIds.js" as LauncherIds

QtObject {
    id: root
    required property var settings
    required property var catalog
    property string query: ""
    property string selectedAppId: ""
    readonly property ApplicationSearchAdapter applications: ApplicationSearchAdapter {
        sourceModel: root.catalog
        query: root.query
    }
    readonly property var selectedApplication: {
        if (!catalog || selectedAppId.length === 0) return null
        catalog.revision
        const app = catalog.application(selectedAppId)
        return app.installed ? app : null
    }
    readonly property bool canAdd: selectedApplication !== null
        && LauncherIds.valid(selectedAppId) && settings.pinnedIds.indexOf(selectedAppId) < 0
        && settings.pinnedIds.length < LauncherIds.maximumPins
    function begin(): void { cancel() }
    function cancel(): void { query = ""; selectedAppId = "" }
    function search(text: string): void { selectedAppId = ""; query = text.slice(0, 256) }
    function select(appId: string): void { selectedAppId = appId }
    function accept(): bool {
        if (!canAdd) return false
        settings.pinnedIds = settings.pinnedIds.concat([selectedAppId])
        cancel()
        return true
    }
}
