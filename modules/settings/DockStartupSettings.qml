// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsCard {
    id: root
    property var autostart: null

    objectName: "dockStartupCard"
    Layout.fillWidth: true
    title: qsTr("Startup")
    SettingsRow {
        Layout.fillWidth: true
        text: qsTr("Start with KDE Plasma")
        showSeparator: false
        Switch {
            objectName: "startWithPlasma"
            Accessible.name: qsTr("Start with KDE Plasma")
            enabled: root.autostart !== null && root.autostart.available
                && !root.autostart.trial
            checked: root.autostart !== null && root.autostart.draftEnabled
            onToggled: if (root.autostart !== null) root.autostart.draftEnabled = checked
        }
    }
    Label {
        objectName: "startupTrialNote"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: root.autostart !== null && root.autostart.trial
        text: qsTr("Available only when Punchi Dock Quickshell is installed for this user. A trial run cannot start it at sign-in.")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
}
