// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Title and actions of the add-item editor. The caller owns what each action means.
RowLayout {
    id: root
    required property bool canAdd
    signal cancelRequested()
    signal addRequested()
    signal discardRequested()

    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing

    Kirigami.Heading {
        text: qsTr("Add item to Dock")
        level: 2
        elide: Text.ElideRight
        Layout.fillWidth: true
        // The title yields space so the header actions never leave the page.
        Layout.preferredWidth: 0
        Layout.minimumWidth: 0
    }
    Button {
        objectName: "cancelAddItem"
        text: qsTr("Back")
        icon.name: "go-previous"
        onClicked: root.cancelRequested()
    }
    Button {
        objectName: "confirmAddItem"
        text: qsTr("Add")
        icon.name: "list-add"
        enabled: root.canAdd
        onClicked: root.addRequested()
    }
    Button {
        objectName: "discardAddItem"
        text: qsTr("Discard")
        icon.name: "edit-delete"
        onClicked: root.discardRequested()
    }
}
