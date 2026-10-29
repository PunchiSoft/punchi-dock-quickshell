// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import Quickshell.Io

// Reads the LICENSE document installed next to shell.qml, so the About page
// presents the same verbatim text as the repository without a network or
// browser round trip.
QtObject {
    id: root
    objectName: "licenseDocument"

    readonly property string path: Quickshell.shellDir + "/LICENSE"
    readonly property bool available: text.length > 0
    property string text: ""

    readonly property FileView file: FileView {
        id: licenseFile
        path: root.path
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.text = licenseFile.text()
        onTextChanged: root.text = licenseFile.text()
        onLoadFailed: root.text = ""
    }
}
