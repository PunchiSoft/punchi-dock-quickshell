// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Section heading of a popup: a bold label followed by the shared divider.
// The dock context and the PunchiMenu application context share it.
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
    PunchiPopupSeparator { Layout.fillWidth: true }
}
