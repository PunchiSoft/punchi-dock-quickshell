// SPDX-License-Identifier: GPL-3.0-or-later
import Punchi.Kde as Native

// Searchable view over the icons installed in the active Plasma icon theme.
Native.IconThemeSearchModel {
    id: root
    readonly property var catalog: Native.IconThemeCatalog {}
    readonly property string themeName: root.catalog.themeName
    readonly property var contexts: root.catalog.contexts
    sourceModel: root.catalog
    readonly property bool loaded: root.catalog.loaded
    readonly property bool loading: root.catalog.loading
    // Enumerating the theme is deferred until the picker needs the names.
    function ensureLoaded(): void {
        if (!root.catalog.loaded) root.catalog.reload()
    }
    function reload(): void { root.catalog.reload() }
}
