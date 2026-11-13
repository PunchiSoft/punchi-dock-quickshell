// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"

RowLayout {
    id: root
    property alias text: heading.text
    property bool textShadow: false
    spacing: Kirigami.Units.smallSpacing * 2
    PunchiPopupShadowLabel {
        id: heading
        shadowEnabled: root.textShadow
        font: {
            const value = Kirigami.Theme.defaultFont
            value.bold = true
            return value
        }
        color: Kirigami.Theme.textColor
        Layout.leftMargin: Kirigami.Units.smallSpacing
    }
    PunchiDockContextSeparator { Layout.fillWidth: true }
}
