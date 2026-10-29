// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Container fields of the add-item editor: name, icon, view and the folder whose
// contents the new container will list, with the entries the owner keeps out.
GridLayout {
    id: root
    required property real labelWidth
    required property bool fanSupported
    property string title: ""
    property string iconName: ""
    property string layoutMode: "grid"
    property string path: ""
    // Entries the new container's popup must skip; empty shows everything.
    property var hiddenEntries: []
    signal titleEdited(string title)
    signal iconNameEdited(string iconName)
    signal layoutEdited(string mode)
    signal pathChosen(string path)
    signal entriesChosen(var names)
    signal iconChooserRequested()

    Layout.fillWidth: true
    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.mediumSpacing

    readonly property var layoutModes: root.fanSupported
        ? ["grid", "list", "detail", "fan"] : ["grid", "list", "detail"]
    readonly property var layoutLabels: root.fanSupported
        ? [qsTr("Grid"), qsTr("List"), qsTr("Detail"), qsTr("Fan")]
        : [qsTr("Grid"), qsTr("List"), qsTr("Detail")]

    function focusName(reason: int): void {
        nameField.forceActiveFocus(reason)
    }
    function focusIconButton(): void {
        iconButton.forceActiveFocus(Qt.TabFocusReason)
    }
    function chooseFolder(): void {
        folderDialog.open()
    }
    function localPath(url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }
    // The chooser writes the draft icon; mirror it into the name field, whose
    // text stops following the property once the user edits it.
    onIconNameChanged: {
        if (iconField && iconField.text !== iconName) iconField.text = iconName
    }

    Label {
        text: qsTr("Name:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    TextField {
        id: nameField
        objectName: "newContainerName"
        Layout.fillWidth: true
        text: root.title
        placeholderText: qsTr("Folder")
        Accessible.name: qsTr("Container name")
        onTextEdited: root.titleEdited(text)
    }

    Label {
        text: qsTr("Icon:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Button {
            id: iconButton
            objectName: "newContainerIconButton"
            icon.name: root.iconName.length > 0 ? root.iconName : "folder"
            display: AbstractButton.IconOnly
            Accessible.name: qsTr("Choose icon")
            ToolTip.text: Accessible.name
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: root.iconChooserRequested()
        }
        TextField {
            id: iconField
            objectName: "newContainerIcon"
            Layout.fillWidth: true
            text: root.iconName
            placeholderText: "folder"
            Accessible.name: qsTr("Icon name")
            onTextEdited: root.iconNameEdited(text)
        }
    }

    Label {
        text: qsTr("View:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    ComboBox {
        objectName: "newContainerLayout"
        Layout.fillWidth: true
        model: root.layoutLabels
        currentIndex: root.layoutModes.indexOf(root.layoutMode)
        Accessible.name: qsTr("Container view")
        onActivated: root.layoutEdited(root.layoutModes[currentIndex])
    }

    Label {
        text: qsTr("Folder:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Label {
            objectName: "newContainerPath"
            Layout.fillWidth: true
            text: root.path.length > 0 ? root.path : qsTr("No folder selected")
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
        }
        Button {
            objectName: "chooseNewContainerFolder"
            text: qsTr("Choose folder…")
            icon.name: "folder-open"
            onClicked: root.chooseFolder()
        }
    }

    // What the popup lists: the folder contents arrive here so the owner
    // can keep entries out before adding the container.
    FolderEntrySelection {
        objectName: "containerEntrySelection"
        Layout.columnSpan: 2
        Layout.fillWidth: true
        // The list lines up with the controls and only grows once a folder
        // is chosen; until then the form shows a single hint line.
        Layout.leftMargin: root.labelWidth + Kirigami.Units.largeSpacing
        Layout.preferredHeight: root.path.length > 0
            ? Kirigami.Units.gridUnit * 10 : -1
        folderPath: root.path
        // The editor lists nothing until a folder is chosen.
        folderChosen: root.path.length > 0
        hiddenEntries: root.hiddenEntries
        onEntriesChosen: function(names) { root.entriesChosen(names) }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose folder")
        onAccepted: root.pathChosen(root.localPath(selectedFolder))
    }
}
