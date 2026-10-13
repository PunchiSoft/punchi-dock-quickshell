// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    id: root
    required property var state
    required property var launcher
    property bool confirming: false
    readonly property bool canEmpty: state.available && state.hasItems && !state.busy
    readonly property string iconName: state.hasItems ? "user-trash-full" : "user-trash"
    signal operationRejected()
    function open(): bool { return launcher.openTrash() }
    function requestEmpty(): bool {
        if (!canEmpty || confirming) return false
        confirming = true
        return true
    }
    function cancel(): void { confirming = false }
    function confirm(): bool {
        if (!confirming) return false
        confirming = false
        if (canEmpty && state.emptyAfterConfirmation()) return true
        operationRejected()
        return false
    }
}
