// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    property bool surfaceVisible: true
    property bool menuOpen: false
    property bool keyboardNavigationRequested: false
    // Like Plasma PanelView: pointer use does not enter AcceptingInput mode.
    readonly property bool acceptsKeyboard: surfaceVisible
        && (menuOpen || keyboardNavigationRequested)
}
