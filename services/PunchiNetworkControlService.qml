// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Wi-Fi radio switch of the default NetworkManager provider. The switch shows
// the provider's confirmed state, never the requested one: a request stays
// pending until the provider reports that value, and a request that never
// arrives keeps the old state with an explicit failure.
QtObject {
    id: root
    property var provider: null
    property bool pending: false
    property bool requestedValue: false
    property string errorCode: ""
    readonly property bool available: root.provider !== null
        && root.provider.available === true
    readonly property bool hardwareEnabled: root.available
        && root.provider.wirelessHardwareEnabled === true
    readonly property bool enabled: root.available
        && root.provider.wirelessEnabled === true
    readonly property bool connected: root.available && root.provider.connected === true
    readonly property string connectionName: root.connected
        ? String(root.provider.connectionName || "") : ""
    readonly property bool actionEnabled: root.available && root.hardwareEnabled && !root.pending
    readonly property string statusText: {
        if (!root.available) return qsTr("Unavailable")
        if (!root.hardwareEnabled) return qsTr("Radio blocked")
        if (root.pending) return qsTr("Applying")
        if (root.errorCode.length > 0) return qsTr("Not confirmed")
        if (root.connected)
            return root.connectionName.length > 0 ? root.connectionName : qsTr("Connected")
        return root.enabled ? qsTr("On") : qsTr("Off")
    }
    readonly property string iconName: root.available && root.enabled
        ? "network-wireless" : "network-wireless-disconnected"
    signal changed()
    readonly property Connections providerChanges: Connections {
        target: root.provider
        function onChanged() {
            if (root.pending && root.provider.wirelessEnabled === root.requestedValue)
                root.finish(true, "")
            root.changed()
        }
    }
    // A bounded wait keeps a provider that silently ignores the request from
    // leaving the control pending forever. The state stays the provider's.
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
    function setEnabled(enabled: bool): bool {
        if (!root.actionEnabled) return false
        if (root.provider.wirelessEnabled === enabled) return true
        root.requestedValue = enabled
        root.pending = true
        root.errorCode = ""
        if (!root.provider.setWirelessEnabled(enabled)) {
            root.finish(false, "unavailable")
            return false
        }
        root.confirmationTimer.restart()
        return true
    }
}
