// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.kirigami as Kirigami

QtObject {
    readonly property int padding: Kirigami.Units.largeSpacing
    readonly property int tailHeight: Kirigami.Units.largeSpacing
    readonly property int gap: Kirigami.Units.largeSpacing
    readonly property real borderWidth: Kirigami.Units.smallSpacing / 4
    readonly property real cornerRadius: Kirigami.Units.cornerRadius * 2
}
