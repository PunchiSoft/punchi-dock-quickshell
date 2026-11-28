// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Punchi.Kde as Native

// Effective Do Not Disturb state of Plasma's notification server. The adapter is
// read-only on purpose: Plasma owns the notification service and has no public
// setter for its persistent mode.
QtObject {
    id: root
    property bool active: false
    readonly property Native.NotificationStateControl control: Native.NotificationStateControl {
        monitoring: root.active
    }
    readonly property bool available: root.control.available
    readonly property bool inhibited: root.control.inhibited
    function refresh(): void { root.control.refresh() }
}
