// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Punchi.Kde as Native

// PowerDevil screen-brightness surface. The native control owns the D-Bus
// boundary; this adapter only names the contract the brightness service reads.
QtObject {
    id: root
    property bool active: false
    readonly property Native.ScreenBrightnessControl control: Native.ScreenBrightnessControl {
        monitoring: root.active
        onOperationFinished: function(displayId, percent, success, error) {
            root.operationFinished(displayId, percent, success, error)
        }
    }
    readonly property bool available: root.control.available
    readonly property var displays: root.control.displays
    readonly property bool pending: root.control.pending
    readonly property string lastTarget: root.control.lastTarget
    readonly property int lastPercent: root.control.lastPercent
    readonly property bool lastSuccess: root.control.lastSuccess
    readonly property string lastError: root.control.lastError
    signal operationFinished(string displayId, int percent, bool success, string error)
    function refresh(): void { root.control.refresh() }
    function setPercent(displayId: string, percent: int): bool {
        return root.control.setPercent(displayId, percent)
    }
}
