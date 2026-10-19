// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

ItemDelegate {
    id: root
    property string iconName
    // A selection is the single primary emphasis. Do not add a second
    // background or frame on another row while the pointer moves.
    property bool selectionActive: false
    hoverEnabled: !root.selectionActive
    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Native.IconThemeRefresh.enabled: true
            source: root.iconName || "application-x-executable"
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }
        Label {
            text: root.text
            textFormat: Text.PlainText
            font: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
