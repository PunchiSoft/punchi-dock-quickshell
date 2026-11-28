// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Do Not Disturb status. Plasma has no public setter for its persistent mode,
// so the row reports the effective state and offers the native notification
// settings instead of simulating a switch Punchi cannot own.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarDoNotDisturbControl"
    spacing: Kirigami.Units.smallSpacing
    signal settingsRequested()
    function focusFirst(): void { settingsButton.forceActiveFocus(Qt.PopupFocusReason) }
    PunchiTopBarControlRow {
        iconName: root.control && root.control.active
            ? "notifications-disabled" : "notifications"
        title: qsTr("Do Not Disturb")
        statusText: root.control ? root.control.statusText : qsTr("Unavailable")
        ToolButton {
            id: settingsButton
            objectName: "topBarDoNotDisturbSettings"
            text: qsTr("Settings")
            font: Kirigami.Theme.smallFont
            Accessible.name: qsTr("Notification settings")
            onClicked: root.settingsRequested()
        }
    }
}
