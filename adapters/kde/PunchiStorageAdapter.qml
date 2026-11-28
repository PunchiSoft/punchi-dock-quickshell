// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Punchi.Kde as Native

// UDisks2 boundary for removable storage. Solid's StorageAccess teardown also
// ejects or powers off the whole drive, which the panel must never do
// implicitly, so the adapter consumes the public UDisks2 objects directly and
// keeps one explicit operation at a time.
QtObject {
    id: root
    property bool active: false
    readonly property Native.StorageControl control: Native.StorageControl {
        monitoring: root.active
        onOperationFinished: function(operation, target, success, error) {
            root.operationFinished(operation, target, success, error)
        }
    }
    readonly property bool available: root.control.available
    readonly property var devices: root.control.devices
    readonly property bool pending: root.control.pending
    readonly property string pendingTarget: root.control.pendingTarget
    readonly property string lastOperation: root.control.lastOperation
    readonly property string lastTarget: root.control.lastTarget
    readonly property bool lastSuccess: root.control.lastSuccess
    readonly property string lastError: root.control.lastError
    signal operationFinished(string operation, string target, bool success, string error)
    function refresh(): void { root.control.refresh() }
    function unmountVolume(blockPath: string): bool { return root.control.unmountVolume(blockPath) }
    function removeDrive(drivePath: string): bool { return root.control.removeDrive(drivePath) }
}
