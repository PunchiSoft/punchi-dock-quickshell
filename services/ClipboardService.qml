// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell

// Single place that writes the session clipboard, so a popup action does not
// depend on the Quickshell provider directly and a caller can inject a
// recording stub.
QtObject {
    function copyText(text: string): bool {
        const value = String(text || "")
        if (value.length === 0) return false
        Quickshell.clipboardText = value
        return true
    }
}
