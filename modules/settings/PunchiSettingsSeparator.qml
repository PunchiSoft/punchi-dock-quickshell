// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Inset hairline used between blocks that are not PunchiSettingsRow instances.
Rectangle {
    objectName: "settingsSeparator"
    height: 1
    Layout.leftMargin: Kirigami.Units.largeSpacing
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b, 0.16)
    Accessible.ignored: true
}
