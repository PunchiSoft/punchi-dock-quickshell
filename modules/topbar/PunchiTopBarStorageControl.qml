// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Removable storage of the provider. Each mounted volume can be unmounted on
// its own; "Safe to remove" on a drive asks the provider to unmount every
// volume of that drive, including a drive with several partitions, and only
// reports success when the provider confirmed the whole request.
ColumnLayout {
    id: root
    property var control: null
    objectName: "topBarStorageControl"
    readonly property var devices: root.control ? root.control.devices : []
    readonly property bool pending: root.control ? root.control.pending === true : false
    readonly property bool available: root.control ? root.control.available === true : false
    visible: root.devices.length > 0
    signal settingsRequested()
    readonly property string outcomeText: {
        if (!root.control || !root.control.lastOperation) return ""
        if (root.control.lastSuccess) return root.control.lastOperation === "unmount"
            ? qsTr("Unmounted") : qsTr("Safe to remove")
        switch (root.control.lastError) {
        case "busy": return qsTr("Busy")
        case "rejected": return qsTr("Rejected")
        case "disconnected": return qsTr("Disconnected")
        case "timeout": return qsTr("Not confirmed")
        case "protected": return qsTr("Protected volume mounted")
        case "not-confirmed": return qsTr("Not confirmed")
        case "not-mounted": return qsTr("Not mounted")
        default: return qsTr("Failed")
        }
    }
    spacing: Kirigami.Units.smallSpacing
    function errorLabel(code): string {
        switch (code) {
        case "busy": return qsTr("Busy")
        case "rejected": return qsTr("Rejected")
        case "disconnected": return qsTr("Disconnected")
        case "protected": return qsTr("Protected volume mounted")
        default: return qsTr("Failed")
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label {
            objectName: "topBarStorageTitle"
            Layout.fillWidth: true
            text: qsTr("Removable storage")
            textFormat: Text.PlainText
            font: Kirigami.Theme.defaultFont
            color: Kirigami.Theme.textColor
        }
        ToolButton {
            objectName: "topBarStorageSettings"
            icon.name: "settings-configure"
            Accessible.name: qsTr("Removable devices settings")
            onClicked: root.settingsRequested()
        }
        Label {
            objectName: "topBarStorageOutcome"
            visible: root.outcomeText.length > 0
            text: root.outcomeText
            textFormat: Text.PlainText
            font: Kirigami.Theme.smallFont
            color: root.control && root.control.lastSuccess === false
                ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
        }
    }
    Label {
        objectName: "topBarStorageEmpty"
        Layout.fillWidth: true
        visible: root.devices.length === 0
        text: root.control && !root.available ? qsTr("Unavailable") : qsTr("No removable storage")
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.disabledTextColor
    }
    Repeater {
        model: root.devices
        delegate: ColumnLayout {
            id: deviceDelegate
            required property var modelData
            objectName: "topBarStorageDevice"
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "drive-removable-media"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    color: Kirigami.Theme.textColor
                    Accessible.ignored: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        Layout.fillWidth: true
                        text: deviceDelegate.modelData.name
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.defaultFont
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: deviceDelegate.modelData.volumes
                        delegate: RowLayout {
                            id: volumeDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Label {
                                Layout.fillWidth: true
                                text: volumeDelegate.modelData.label
                                textFormat: Text.PlainText
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                            }
                            ToolButton {
                                objectName: "topBarStorageUnmount"
                                text: qsTr("Unmount")
                                font: Kirigami.Theme.smallFont
                                enabled: !root.pending && root.control !== null
                                visible: volumeDelegate.modelData.mounted === true
                                Accessible.name: qsTr("Unmount %1").arg(volumeDelegate.modelData.label)
                                onClicked: if (root.control) root.control.unmountVolume(volumeDelegate.modelData.path)
                            }
                        }
                    }
                }
                ToolButton {
                    objectName: "topBarStorageRemove"
                    text: qsTr("Safe to remove")
                    font: Kirigami.Theme.smallFont
                    enabled: !root.pending && root.control !== null
                        && deviceDelegate.modelData.canRemove !== false
                    Accessible.name: qsTr("Safely remove %1").arg(deviceDelegate.modelData.name)
                    onClicked: if (root.control) root.control.removeDrive(deviceDelegate.modelData.id)
                }
            }
        }
    }
}
