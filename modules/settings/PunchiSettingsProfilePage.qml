// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Import and export are explicit user actions. The exchange service validates
// the selected file and prepares a preview; this page owns the confirmation and
// never writes the live profile itself.
Item {
    id: root
    required property var exchange
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function focusFirst(): void { importButton.forceActiveFocus(Qt.OtherFocusReason) }

    ColumnLayout {
        id: layout
        width: root.width
        height: layout.implicitHeight
        spacing: Kirigami.Units.largeSpacing

        PunchiSettingsCard {
            objectName: "dockProfileCard"
            Layout.fillWidth: true
            title: qsTr("Configuration file")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        objectName: "dockProfileDescription"
                        Layout.fillWidth: true
                        text: qsTr("A profile is a portable JSON file.")
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            objectName: "dockProfileIncludesLabel"
                            Layout.alignment: Qt.AlignTop
                            text: qsTr("Includes:")
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                        }
                        Label {
                            objectName: "dockProfileIncludes"
                            Layout.fillWidth: true
                            text: qsTr("dock items and their order, folder containers and dock preferences.")
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            objectName: "dockProfileExcludesLabel"
                            Layout.alignment: Qt.AlignTop
                            text: qsTr("Does not include:")
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                        }
                        Label {
                            objectName: "dockProfileExcludes"
                            Layout.fillWidth: true
                            text: qsTr("autostart, KDE settings, files on disk or live state such as open windows and update counts.")
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.mediumSpacing
                    Button {
                        id: importButton
                        objectName: "importDockProfile"
                        text: qsTr("Import…")
                        icon.name: "document-open"
                        Accessible.name: qsTr("Import profile")
                        onClicked: importDialog.open()
                    }
                    Button {
                        objectName: "exportDockProfile"
                        text: qsTr("Export…")
                        icon.name: "document-save-as"
                        Accessible.name: qsTr("Export profile")
                        onClicked: exportDialog.open()
                    }
                }
                Label {
                    objectName: "dockProfileExportNote"
                    Layout.fillWidth: true
                    text: qsTr("Export includes pending changes.")
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
                Label {
                    objectName: "dockProfileNotice"
                    Layout.fillWidth: true
                    visible: root.exchange.notice.length > 0
                    text: root.exchange.notice
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: root.exchange.noticeIsError
                        ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    Accessible.name: qsTr("Profile status")
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    FileDialog {
        id: importDialog
        objectName: "importProfileDialog"
        title: qsTr("Import dock profile")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Profile files (*.json)"), qsTr("All files (*)")]
        onAccepted: root.exchange.importFrom(selectedFile)
    }
    Connections {
        target: root.exchange
        function onImportReady() { Qt.callLater(importConfirmation.open) }
    }
    FileDialog {
        id: exportDialog
        objectName: "exportProfileDialog"
        title: qsTr("Export dock profile")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("Profile files (*.json)"), qsTr("All files (*)")]
        onAccepted: root.exchange.exportTo(selectedFile)
    }
    Kirigami.PromptDialog {
        id: importConfirmation
        objectName: "dockProfileImportConfirmation"
        parent: Overlay.overlay
        title: qsTr("Replace profile?")
        subtitle: qsTr("The file contains %1. Current values will be replaced. Changes remain pending until you apply or accept them.")
            .arg(root.exchange.pendingSummary)
        preferredWidth: Kirigami.Units.gridUnit * 30
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                objectName: "confirmProfileImport"
                text: qsTr("Replace")
                icon.name: "dialog-ok"
                onTriggered: {
                    root.exchange.confirmImport()
                    importConfirmation.close()
                }
            }
        ]
        onRejected: root.exchange.cancelImport()
        onClosed: if (root.exchange.hasPending) root.exchange.cancelImport()
        onOpened: {
            const cancel = importConfirmation.standardButton(Kirigami.Dialog.Cancel)
            if (cancel) cancel.forceActiveFocus(Qt.PopupFocusReason)
        }
    }
}
