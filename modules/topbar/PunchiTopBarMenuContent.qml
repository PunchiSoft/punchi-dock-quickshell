// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact Punchi menu of the top panel. "Applications" hands the fullscreen
// menu to the existing controller on the screen that owns this bar; "Dock
// settings" opens the settings window the dock already uses.
ColumnLayout {
    id: root
    objectName: "topBarMenuContent"
    signal applicationsRequested()
    signal dockSettingsRequested()
    spacing: 0
    function focusFirst(): void { applications.forceActiveFocus(Qt.PopupFocusReason) }
    ItemDelegate {
        id: applications
        objectName: "topBarApplications"
        Layout.fillWidth: true
        text: qsTr("Applications")
        icon.name: "view-grid"
        Accessible.name: text
        onClicked: root.applicationsRequested()
    }
    ItemDelegate {
        objectName: "topBarDockSettings"
        Layout.fillWidth: true
        text: qsTr("Dock settings")
        icon.name: "preferences-system"
        Accessible.name: text
        onClicked: root.dockSettingsRequested()
    }
}
