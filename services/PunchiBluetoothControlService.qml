// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Bluetooth adapter switch. The provider reports adapter presence, power and
// the blocked state, so an absent, disabled and blocked adapter stay distinct.
// Pairing and discovery stay with KDE: this control only changes the radio.
QtObject {
    id: root
    property var provider: null
    property bool pending: false
    property bool requestedValue: false
    property string errorCode: ""
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property bool blocked: root.available && root.provider.blocked === true
    readonly property bool powered: root.available && root.provider.powered === true
    readonly property int adapterCount: root.provider !== null
        ? Number(root.provider.adapterCount || 0) : 0
    readonly property string adapterName: root.provider !== null
        ? String(root.provider.adapterName || "") : ""
    readonly property bool actionEnabled: root.available && !root.blocked && !root.pending
    readonly property string statusText: {
        if (!root.available) return qsTr("No adapter")
        if (root.blocked) return qsTr("Blocked")
        if (root.pending) return qsTr("Applying")
        if (root.errorCode.length > 0) return qsTr("Not confirmed")
        if (!root.powered) return qsTr("Off")
        return root.adapterName.length > 0 ? root.adapterName : qsTr("On")
    }
    readonly property string iconName: root.available
        ? (root.powered ? "network-bluetooth-activated" : "network-bluetooth-inactive")
        : "network-bluetooth-inactive"
    signal changed()
    readonly property Connections providerChanges: Connections {
        target: root.provider
        function onChanged() {
            if (root.pending && root.provider.powered === root.requestedValue)
                root.finish(true, "")
            root.changed()
        }
    }
    readonly property Timer confirmationTimer: Timer {
        interval: 20000
        repeat: false
        onTriggered: if (root.pending) root.finish(false, "timeout")
    }
    function finish(success: bool, error: string): void {
        root.pending = false
        root.errorCode = success ? "" : error
        root.confirmationTimer.stop()
    }
    function setPowered(powered: bool): bool {
        if (!root.actionEnabled) return false
        if (root.provider.powered === powered) return true
        root.requestedValue = powered
        root.pending = true
        root.errorCode = ""
        if (!root.provider.setPowered(powered)) {
            root.finish(false, "unavailable")
            return false
        }
        root.confirmationTimer.restart()
        return true
    }
}
