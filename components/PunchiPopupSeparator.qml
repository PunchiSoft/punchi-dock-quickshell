// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami

// Shared divider between groups of popup rows. The dock context, its sections
// and the PunchiMenu application context reuse it, so a menu never invents a
// second hairline colour or thickness.
Rectangle {
    implicitWidth: Kirigami.Units.gridUnit
    implicitHeight: Kirigami.Units.smallSpacing / 4
    color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
    Accessible.ignored: true
}
