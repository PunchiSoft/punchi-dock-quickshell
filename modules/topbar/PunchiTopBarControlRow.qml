// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Shared row of the quick controls: provider icon, name, confirmed status and
// the trailing control that changes the provider.
RowLayout {
    id: root
    property string iconName: ""
    property string title: ""
    property string statusText: ""
    property bool statusActive: false
    default property alias trailing: trailingRow.data
    spacing: Kirigami.Units.mediumSpacing
    Kirigami.Icon {
        objectName: "topBarControlIcon"
        source: root.iconName
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        Layout.alignment: Qt.AlignVCenter
        color: Kirigami.Theme.textColor
        Accessible.ignored: true
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Label {
            objectName: "topBarControlTitle"
            Layout.fillWidth: true
            text: root.title
            textFormat: Text.PlainText
            font: Kirigami.Theme.defaultFont
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
        }
        Label {
            objectName: "topBarControlStatus"
            Layout.fillWidth: true
            visible: root.statusText.length > 0
            text: root.statusText
            textFormat: Text.PlainText
            font: Kirigami.Theme.smallFont
            color: root.statusActive ? Kirigami.Theme.textColor
                : Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
    }
    RowLayout {
        id: trailingRow
        spacing: Kirigami.Units.smallSpacing
        Layout.alignment: Qt.AlignVCenter
    }
}
