// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.kirigami as Kirigami

QtObject {
    readonly property bool reducedMotion: Kirigami.Units.shortDuration <= 0
    readonly property int clickDuration: reducedMotion ? 0 : Kirigami.Units.longDuration
    // Hover wave: the pointer maps directly to the scale, so only the amplitude
    // fade is timed. A longer fade reads as softer without losing tracking.
    readonly property int enterDuration: Math.max(100, Math.round(Kirigami.Units.shortDuration * 1.5))
    readonly property int leaveDuration: Math.max(80, Math.round(Kirigami.Units.shortDuration * 1.2))
    // Auto-hide travel: one eased slide, separate from the click bounce so
    // tuning one does not retime the other.
    readonly property int slideDuration: Math.max(200, Math.round(Kirigami.Units.longDuration * 1.5))
}
