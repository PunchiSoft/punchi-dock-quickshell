// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"

PunchiSettingsCard {
    id: root
    required property PunchiShellSettings settings
    required property var updates
    // Names the sources that really answered, so the note never promises a
    // source the distribution does not provide. Hidden while nothing is known.
    readonly property string updateSourcesText: {
        if (root.updates === null) return ""
        const sources = root.updates.availableSources || []
        if (sources.length === 0) return ""
        const names = []
        for (const source of sources) {
            if (source === "system") {
                const backend = root.updates.backendName || ""
                names.push(backend.length > 0 ? backend : qsTr("system packages"))
            } else if (source === "flatpak") {
                names.push(qsTr("Flatpak"))
            } else if (source === "firmware") {
                names.push(qsTr("firmware"))
            }
        }
        return qsTr("Updates from %1").arg(names.join(" · "))
    }

    objectName: "dockUpdatesCard"
    Layout.fillWidth: true
    title: qsTr("Updates")
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Show available updates")
        showSeparator: false
        Switch {
            objectName: "updateBadgeEnabled"
            Accessible.name: qsTr("Show available updates")
            checked: root.settings.updateBadgeEnabled
            onToggled: root.settings.updateBadgeEnabled = checked
        }
    }
    Label {
        objectName: "updateBadgeSourcesNote"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: root.updateSourcesText.length > 0
        text: root.updateSourcesText
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
}
