// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Do Not Disturb as Plasma reports it. A service name alone is not a state: the
// row shows On or Off only after the async read produced a boolean for the
// current owner. A pending first read, a failed read or an invalid type stays
// unavailable, and configuration is delegated to KDE's notification settings.
QtObject {
    id: root
    property var provider: null
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property bool reading: root.provider !== null
        && root.provider.reading === true
    readonly property bool valid: root.provider !== null
        && root.provider.valid === true
    readonly property bool active: root.available && root.valid
        && root.provider.inhibited === true
    readonly property string statusText: !root.available ? qsTr("Unavailable")
        : root.reading && !root.valid ? qsTr("Checking")
        : !root.valid ? qsTr("Unavailable")
        : root.active ? qsTr("On") : qsTr("Off")
}
