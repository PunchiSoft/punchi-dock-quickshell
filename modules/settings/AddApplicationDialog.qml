// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

Dialog {
    id: root
    required property var controller
    property Item hostItem: null
    property real hostWidth: parent ? parent.width : 0
    property real hostHeight: parent ? parent.height : 0
    signal searchRequested(string text)
    signal selectionRequested(string appId)
    signal addRequested()
    title: qsTr("Add item to Dock")
    objectName: "addApplicationDialog"
    parent: hostItem && hostItem.Window.window ? hostItem.Window.window.contentItem : null
    popupType: Popup.Item
    modal: true
    focus: true
    width: Math.min(Kirigami.Units.gridUnit * 32, Math.max(0, hostWidth - Kirigami.Units.largeSpacing * 2))
    height: Math.min(implicitHeight, Math.max(0, hostHeight - Kirigami.Units.largeSpacing * 2))
    x: (hostWidth - width) / 2
    y: (hostHeight - height) / 2
    closePolicy: Popup.CloseOnEscape
    onOpened: search.forceActiveFocus(Qt.PopupFocusReason)
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing
        Label { text: qsTr("Application"); font.bold: true }
        TextField {
            id: search
            objectName: "applicationSearch"
            Layout.fillWidth: true
            placeholderText: qsTr("Name or alias")
            Accessible.name: qsTr("Search applications")
            text: root.controller.query
            onTextEdited: root.searchRequested(text)
        }
        ScrollView {
            objectName: "applicationResultsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ListView {
                id: applications
                objectName: "applicationSearchResults"
                model: root.visible ? root.controller.applications : null
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: ApplicationListRow {
                    required property string appId
                    required property string name
                    required property string appIconName
                    iconName: appIconName
                    objectName: "applicationResult-" + appId
                    width: ListView.view.width
                    text: name
                    highlighted: root.controller.selectedAppId === appId
                    onClicked: root.selectionRequested(appId)
                    Keys.onReturnPressed: root.selectionRequested(appId)
                }
            }
        }
        GridLayout {
            objectName: "applicationDetails"
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.mediumSpacing
            Label {
                objectName: "applicationNameLabel"
                text: qsTr("Name:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Label {
                objectName: "applicationNameValue"
                text: root.controller.selectedApplication ? root.controller.selectedApplication.name : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                objectName: "applicationIconLabel"
                text: qsTr("Icon:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Kirigami.Icon {
                Native.IconThemeRefresh.enabled: true
                objectName: "applicationPreviewIcon"
                source: root.controller.selectedApplication ? root.controller.selectedApplication.appIconName : "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Accessible.ignored: true
            }
            Label {
                objectName: "applicationDescriptionLabel"
                text: qsTr("Description:")
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            }
            Label {
                objectName: "applicationDescriptionValue"
                text: root.controller.selectedApplication ? root.controller.selectedApplication.description : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Item { Layout.fillWidth: true }
            Button {
                objectName: "confirmAddApplication"
                text: qsTr("Add")
                icon.name: "list-add"
                enabled: root.controller.canAdd
                onClicked: root.addRequested()
            }
            Button {
                objectName: "discardAddApplication"
                text: qsTr("Discard")
                onClicked: root.reject()
            }
        }
    }
}
