// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Punchi.Kde as Native

// Singleton access to the buttons of the selected Aurorae decoration. A consumer
// names a role and reads `paths`; it never builds a path inside the theme.
QtObject {
    readonly property var provider: Native.DecorationButtonProvider

    readonly property var paths: Native.DecorationButtonProvider.buttonPaths
    readonly property size buttonSize: Native.DecorationButtonProvider.buttonSize
    readonly property string themeName: Native.DecorationButtonProvider.themeName

    function pathFor(role: string): string {
        return String(Native.DecorationButtonProvider.buttonPaths[role] || "")
    }
    function refresh(): void {
        Native.DecorationButtonProvider.refresh()
    }
}
