// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    property alias text: heading.text
    spacing: Kirigami.Units.smallSpacing * 2
    Label {
        id: heading
        font: {
            const value = Kirigami.Theme.defaultFont
            value.bold = true
            return value
        }
        color: Kirigami.Theme.textColor
        Layout.leftMargin: Kirigami.Units.smallSpacing
    }
    DockContextSeparator { Layout.fillWidth: true }
}
