// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Quiet grouped surface for the compact quick controls. It carries no action of
// its own; the rows inside keep their provider state, focus and accessible names.
Rectangle {
    id: root
    default property alias content: sectionColumn.data
    property real padding: Kirigami.Units.smallSpacing
    property real spacing: Kirigami.Units.smallSpacing
    implicitWidth: sectionColumn.implicitWidth + root.padding * 2
    implicitHeight: sectionColumn.implicitHeight + root.padding * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.alpha(Kirigami.Theme.alternateBackgroundColor, 0.55)
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
    ColumnLayout {
        id: sectionColumn
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.spacing
    }
}
