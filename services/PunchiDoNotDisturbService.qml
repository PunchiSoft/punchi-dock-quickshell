// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Do Not Disturb as Plasma reports it. There is no direct write in the public
// notification interface, so the row shows the effective state and delegates
// configuration to KDE's notification settings.
QtObject {
    id: root
    property var provider: null
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property bool active: root.available && root.provider.inhibited === true
    readonly property string statusText: !root.available ? qsTr("Unavailable")
        : root.active ? qsTr("On") : qsTr("Off")
}
