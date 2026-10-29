// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Grouped settings card: a small group label above a rounded frame whose rows
// are separated by inset hairlines. The frame samples the shared settings
// surface so the fill and the rounded corners stay visible in every scheme.
ColumnLayout {
    id: root
    objectName: "settingsCard"
    property string title: ""
    default property alias cardContent: contentColumn.data
    readonly property real inset: Kirigami.Units.largeSpacing
    spacing: Kirigami.Units.smallSpacing
    Label {
        objectName: "settingsCardTitle"
        Layout.fillWidth: true
        Layout.leftMargin: root.inset
        visible: root.title.length > 0
        text: root.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.weight: Font.DemiBold
        color: Kirigami.Theme.textColor
    }
    PunchiSettingsCardFrame {
        id: frame
        objectName: "settingsCardFrame"
        Layout.fillWidth: true
        implicitHeight: contentColumn.implicitHeight
        ColumnLayout {
            id: contentColumn
            objectName: "settingsCardContent"
            width: parent.width
            spacing: 0
        }
    }
}
