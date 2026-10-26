// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml

QtObject {
    id: root
    required property var contents
    property var opener: null
    property url rootLocation: contents.downloadsUrl
    property string rootTitle: ""
    property string title: rootTitle
    property var history: []
    // Whether activating a directory enters it. When the owner turns this off,
    // the same activation opens the directory in the file manager, so the entry
    // still leads somewhere.
    property bool browseSubfolders: true
    property url selectedUrl: ""
    property real scrollPosition: 0
    readonly property bool canGoBack: history.length > 0
    readonly property int selectedIndex: {
        contents.revision
        const index = selectedUrl.toString().length ? contents.indexOfUrl(selectedUrl) : -1
        return index >= 0 ? index : contents.count > 0 ? 0 : -1
    }
    signal openDispatched()
    signal operationRejected()
    signal restoreRequested()
    function begin(): void {
        history = []; selectedUrl = ""; scrollPosition = 0; title = rootTitle
        contents.location = rootLocation
        contents.active = true
    }
    function finish(): void { contents.active = false }
    function select(index: int): void {
        const entry = contents.get(index)
        if (entry.entryUrl) selectedUrl = entry.entryUrl
    }
    function activate(index: int): bool {
        const entry = contents.get(index)
        if (!entry.entryUrl) return false
        if (entry.directory && !root.browseSubfolders) return open(entry.entryUrl)
        if (entry.directory) {
            history = history.concat([{location: contents.location, title,
                selectedUrl: entry.entryUrl, scrollPosition}])
            selectedUrl = ""; scrollPosition = 0; title = entry.entryName
            contents.location = entry.entryUrl
            restoreRequested()
            return true
        }
        return open(entry.entryUrl)
    }
    // Fan rows are a leaf: a directory opens in the file manager instead of
    // replacing the arc with its contents.
    function openEntry(index: int): bool {
        const entry = contents.get(index)
        if (!entry.entryUrl) return false
        return open(entry.entryUrl)
    }
    function back(): void {
        if (!canGoBack) return
        const next = history.slice()
        const previous = next.pop()
        history = next
        title = previous.title; selectedUrl = previous.selectedUrl
        scrollPosition = previous.scrollPosition
        contents.location = previous.location
        restoreRequested()
    }
    function open(location: url): bool {
        if (opener && opener.openFolderUrl(contents, location)) { openDispatched(); return true }
        operationRejected()
        return false
    }
    function openLocation(): bool { return open(contents.location) }
    // Local path behind a listing URL, used by the actions that copy or reveal
    // an entry. A remote or malformed location resolves to an empty string, so
    // the caller can disable the action instead of copying nonsense.
    function localPath(location): string {
        const text = String(location || "")
        if (!text.startsWith("file://")) return ""
        try {
            return decodeURIComponent(text.slice(7))
        } catch (error) {
            return ""
        }
    }
}
