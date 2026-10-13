// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

Pane {
    id: root
    required property string questionText
    required property string warningText
    property bool canConfirm: false
    signal confirmRequested()
    signal cancelRequested()
    padding: Kirigami.Units.largeSpacing * 2
    implicitWidth: Kirigami.Units.gridUnit * 19
    implicitHeight: content.implicitHeight + topPadding + bottomPadding
    font: Kirigami.Theme.defaultFont
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Accessible.role: Accessible.Dialog
    Accessible.name: questionText
    Accessible.description: warningText
    background: Kirigami.ShadowedRectangle {
        radius: Kirigami.Units.cornerRadius * 2
        color: Kirigami.Theme.backgroundColor
        border.width: Kirigami.Units.smallSpacing / 4
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        shadow.size: Kirigami.Units.largeSpacing * 2
        shadow.color: Qt.alpha(root.palette.shadow, 0.35)
    }
    function focusFirst(): void { cancel.forceActiveFocus(Qt.TabFocusReason) }
    Keys.onEscapePressed: root.cancelRequested()
    contentItem: ColumnLayout {
        id: content
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            source: "user-trash-full"
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            Layout.alignment: Qt.AlignHCenter
            Accessible.ignored: true
        }
        Label {
            Layout.fillWidth: true
            text: root.questionText
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            text: root.warningText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Button {
                id: cancel
                objectName: "cancelEmptyTrash"
                Layout.fillWidth: true
                text: qsTr("Cancel")
                onClicked: root.cancelRequested()
                KeyNavigation.tab: confirm.enabled ? confirm : cancel
                KeyNavigation.backtab: confirm.enabled ? confirm : cancel
            }
            Button {
                id: confirm
                objectName: "confirmEmptyTrash"
                Layout.fillWidth: true
                text: qsTr("Empty Trash")
                icon.name: "edit-delete"
                enabled: root.canConfirm
                highlighted: true
                onClicked: root.confirmRequested()
                KeyNavigation.tab: cancel
                KeyNavigation.backtab: cancel
            }
        }
    }
}
