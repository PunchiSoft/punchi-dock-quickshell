// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Wi-Fi radio switch. The switch position is updated from the service's
// confirmed state, never from the click, so a rejected or unconfirmed request
// leaves the provider's real state visible.
ColumnLayout {
    id: root
    property var control: null
    property bool compact: false
    objectName: "topBarWifiControl"
    signal settingsRequested()
    spacing: Kirigami.Units.smallSpacing
    function focusFirst(): void { toggle.forceActiveFocus(Qt.PopupFocusReason) }
    function syncChecked(): void {
        if (root.control) toggle.checked = root.control.enabled
    }
    Component.onCompleted: syncChecked()
    onControlChanged: syncChecked()
    PunchiTopBarControlRow {
        iconName: root.control ? root.control.iconName : "network-wireless-disconnected"
        title: qsTr("Wi-Fi")
        statusText: root.control ? root.control.statusText : qsTr("Unavailable")
        statusActive: root.control !== null && root.control.connected
        compact: root.compact
        ToolButton {
            objectName: "topBarWifiSettings"
            icon.name: "settings-configure"
            icon.width: root.compact ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
            icon.height: root.compact ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
            padding: root.compact ? 0 : Kirigami.Units.smallSpacing
            Accessible.name: qsTr("Network settings")
            onClicked: root.settingsRequested()
        }
        Switch {
            id: toggle
            objectName: "topBarWifiSwitch"
            Accessible.name: qsTr("Wi-Fi")
            enabled: root.control !== null && root.control.actionEnabled
            onCheckedChanged: if (root.control && checked !== root.control.enabled) root.control.setEnabled(checked)
            readonly property Connections stateChanges: Connections {
                target: root.control
                function onEnabledChanged() { if (!toggle.pressed) toggle.checked = root.control.enabled }
                function onPendingChanged() { if (!root.control.pending) toggle.checked = root.control.enabled }
                function onErrorCodeChanged() { toggle.checked = root.control.enabled }
            }
        }
    }
}
