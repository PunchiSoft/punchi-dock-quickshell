// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell.Bluetooth

// Bluetooth adapters through Quickshell's BlueZ provider. The provider exposes
// the real adapter state, including the Blocked state, so the control can tell
// an absent adapter from a powered-off or blocked one.
QtObject {
    id: root
    property bool active: false
    readonly property var adapterList: {
        const model = Bluetooth.adapters
        return model && model.values ? model.values : []
    }
    readonly property int adapterCount: root.adapterList.length
    // BlueDevil's own activation loop uses every adapter. A separate client
    // keeps a single choice: the provider default, otherwise the first adapter.
    readonly property var providerAdapter: Bluetooth.defaultAdapter
    readonly property var adapter: root.providerAdapter !== null
        ? root.providerAdapter : (root.adapterList.length > 0 ? root.adapterList[0] : null)
    readonly property bool available: root.active && root.adapterCount > 0
    readonly property string adapterName: root.adapter
        ? String(root.adapter.name || root.adapter.adapterId || "") : ""
    readonly property bool powered: root.adapter ? root.adapter.enabled === true : false
    readonly property bool blocked: root.adapter
        ? root.adapter.state === BluetoothAdapterState.Blocked : false
    signal changed()

    function setPowered(powered: bool): bool {
        if (!root.ready || !root.adapter) return false
        if (root.blocked && powered) return false
        root.adapter.enabled = powered
        return true
    }
    readonly property bool ready: root.available && root.adapter !== null
    readonly property Connections adapterChanges: Connections {
        target: root.adapter
        function onEnabledChanged() { root.changed() }
        function onStateChanged() { root.changed() }
        function onNameChanged() { root.changed() }
    }
    readonly property Connections bluezChanges: Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() { root.changed() }
    }
}
