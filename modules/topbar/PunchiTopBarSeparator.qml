// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Hairline between two quick-control sections.
Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b, 0.14)
    Accessible.ignored: true
}
