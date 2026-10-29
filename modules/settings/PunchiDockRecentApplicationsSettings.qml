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
    property var recentApplications: null
    // The note follows KDE's own preference only. Gating a dock switch on the
    // service state made it impossible to turn the list back on, because
    // hiding the list is what stops the service from being queried.
    readonly property bool kdeTrackingActive: root.recentApplications === null
        || root.recentApplications.trackingEnabled

    objectName: "dockRecentCard"
    Layout.fillWidth: true
    title: qsTr("Recent applications")
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Show recent applications")
        showSeparator: true
        Switch {
            objectName: "recentApplicationsEnabled"
            Accessible.name: qsTr("Show recent applications")
            checked: root.settings.recentApplicationsEnabled
            onToggled: root.settings.recentApplicationsEnabled = checked
        }
    }
    PunchiSettingsRow {
        objectName: "recentApplicationsTrackingRow"
        Layout.fillWidth: true
        visible: root.recentApplications !== null
        text: qsTr("Remember application history in KDE")
        showSeparator: true
        Switch {
            id: trackingSwitch
            objectName: "recentApplicationsTracking"
            Accessible.name: qsTr("Remember application history in KDE")
            checked: root.recentApplications !== null && root.recentApplications.trackingEnabled
            onToggled: {
                const service = root.recentApplications
                if (service === null) return
                service.setTrackingEnabled(checked)
                // The gesture breaks the declarative binding; KDE stays the
                // source of truth for external changes.
                checked = Qt.binding(function() { return service.trackingEnabled })
            }
        }
    }
    PunchiSettingsRow {
        objectName: "recentApplicationsKdeRow"
        Layout.fillWidth: true
        visible: root.recentApplications !== null
        text: qsTr("KDE recent files options")
        showSeparator: true
        Button {
            objectName: "recentApplicationsKdeSettings"
            Accessible.name: qsTr("Open KDE Recent Files settings")
            text: qsTr("Open settings")
            onClicked: root.recentApplications.openTrackingSettings()
        }
    }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Presentation")
        showSeparator: true
        ComboBox {
            objectName: "recentApplicationsPresentation"
            Accessible.name: qsTr("Recent applications presentation")
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            model: [qsTr("Icons"), qsTr("Container")]
            currentIndex: root.settings.recentApplicationsPresentation === "container" ? 1 : 0
            enabled: root.settings.recentApplicationsEnabled
            onActivated: root.settings.recentApplicationsPresentation =
                currentIndex === 1 ? "container" : "icons"
        }
    }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Applications to show")
        showSeparator: true
        SpinBox {
            objectName: "recentApplicationsCount"
            Accessible.name: qsTr("Applications to show")
            from: 1
            to: 20
            value: root.settings.recentApplicationsCount
            enabled: root.settings.recentApplicationsEnabled
            onValueModified: root.settings.recentApplicationsCount = value
        }
    }
    PunchiSettingsRow {
        Layout.fillWidth: true
        text: qsTr("Container view")
        showSeparator: false
        ComboBox {
            id: recentContainerView
            objectName: "recentApplicationsContainerLayout"
            Accessible.name: qsTr("Recent applications container view")
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: Math.max(implicitWidth, Kirigami.Units.gridUnit * 11)
            // The arc needs a top or bottom edge, so a side dock offers the
            // three flat views; the stored choice survives the edge change.
            readonly property var layoutModes: root.settings.fanSupported
                ? ["grid", "list", "detail", "fan"] : ["grid", "list", "detail"]
            model: root.settings.fanSupported
                ? [qsTr("Grid"), qsTr("List"), qsTr("Detail"), qsTr("Fan")]
                : [qsTr("Grid"), qsTr("List"), qsTr("Detail")]
            currentIndex: Math.max(0,
                layoutModes.indexOf(root.settings.effectiveRecentApplicationsLayout))
            enabled: root.settings.recentApplicationsEnabled
                && root.settings.recentApplicationsPresentation === "container"
            onActivated: root.settings.recentApplicationsContainerLayout =
                layoutModes[currentIndex]
        }
    }
    Label {
        objectName: "recentApplicationsUnavailableNote"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: !root.kdeTrackingActive
        text: qsTr("KDE is not saving application history. Set System Settings → Recent Files to remember applications to fill this list.")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
}
