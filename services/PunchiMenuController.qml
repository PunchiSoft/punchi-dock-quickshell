// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

// Which screen owns the fullscreen menu. One instance serves every screen so
// two surfaces can never both claim the keyboard, and the dock item, the IPC
// handler and the surfaces all speak to the same owner.
QtObject {
    id: root

    property string openScreenKey: ""
    signal opened(string screenKey)
    signal closed()

    function isOpen(screenKey: string): bool {
        return root.openScreenKey.length > 0 && root.openScreenKey === screenKey
    }
    function open(screenKey: string): bool {
        if (screenKey.length === 0) return false
        if (root.openScreenKey === screenKey) return true
        root.openScreenKey = screenKey
        root.opened(screenKey)
        return true
    }
    function close(): bool {
        if (root.openScreenKey.length === 0) return false
        root.openScreenKey = ""
        root.closed()
        return true
    }
    function toggle(screenKey: string): bool {
        if (root.isOpen(screenKey)) return root.close()
        return root.open(screenKey)
    }
}
