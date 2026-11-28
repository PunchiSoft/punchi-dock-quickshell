// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell.Networking

// Wi-Fi state of NetworkManager through Quickshell's networking provider. The
// adapter is the only place that touches the NetworkManager model; the service
// owns the pending/confirmation presentation rule.
QtObject {
    id: root
    property bool active: false
    readonly property var deviceList: {
        const model = Networking.devices
        return model && model.values ? model.values : []
    }
    readonly property var wifiDevice: {
        for (const device of root.deviceList)
            if (device && device.type === DeviceType.Wifi) return device
        return null
    }
    readonly property bool available: root.active
        && Networking.backend !== NetworkBackendType.None
    readonly property bool wirelessEnabled: root.active && Networking.wifiEnabled === true
    readonly property bool wirelessHardwareEnabled: root.active
        && Networking.wifiHardwareEnabled === true
    readonly property bool connected: root.active && root.wifiDevice !== null
        && root.wifiDevice.connected === true
    // Name of the connected network as NetworkManager reports it. Empty while
    // disconnected, so the view never invents a network name.
    readonly property string connectionName: {
        if (!root.connected) return ""
        const model = root.wifiDevice ? root.wifiDevice.networks : null
        const networks = model && model.values ? model.values : []
        for (const network of networks)
            if (network && network.connected === true) return String(network.name || "")
        return ""
    }
    signal changed()

    function setWirelessEnabled(enabled: bool): bool {
        if (!root.available || !root.wirelessHardwareEnabled) return false
        Networking.requestSetWifiEnabled(enabled)
        return true
    }
    readonly property Connections networkingChanges: Connections {
        target: Networking
        function onWifiEnabledChanged() { root.changed() }
        function onWifiHardwareEnabledChanged() { root.changed() }
    }
    readonly property Connections deviceChanges: Connections {
        target: root.wifiDevice
        function onConnectedChanged() { root.changed() }
    }
    onDeviceListChanged: root.changed()
}
