// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Trash fields of the add-item editor. The item has no editable name or icon; the
// only state is whether the dock already carries it.
GridLayout {
    id: root
    required property real labelWidth
    required property bool alreadyPinned

    Layout.fillWidth: true
    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.mediumSpacing

    Label {
        text: qsTr("Name:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    Label {
        text: qsTr("Trash")
        font.bold: true
        Layout.fillWidth: true
    }

    Label {
        text: qsTr("Icon:")
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredWidth: root.labelWidth
        opacity: 0.8
    }
    Kirigami.Icon {
        objectName: "newTrashPreview"
        source: "user-trash"
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large
        Accessible.ignored: true
    }

    Item {
        visible: root.alreadyPinned
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.smallSpacing
    }
    Label {
        visible: root.alreadyPinned
        Layout.columnSpan: 2
        Layout.fillWidth: true
        color: Kirigami.Theme.neutralTextColor
        text: qsTr("Trash is already present in the dock.")
    }
}
