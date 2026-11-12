// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Geometry of the fullscreen menu grid, measured from the owner's macOS
// Launchpad reference at 1440x900: seven columns, five rows, roughly 86 px
// icons and 182.5 x 142 px cell pitches. The view preserves these proportions
// with S = min(W / W0, H / H0); the cells stay rectangular and the selection
// card is the square inside each cell. Keep the source and the tested
// resolutions with these numbers when they change.
QtObject {
    id: root

    readonly property int referenceColumns: 7
    readonly property int referenceRows: 5
    readonly property real referenceCellWidth: 182.5
    readonly property real referenceCellHeight: 142
    readonly property real referenceIconSize: 86
    readonly property int referenceLabelSize: 14
    // The card is the square inside the cell; an inset can add air without
    // changing the cell pitch.
    readonly property real cardInset: 0
}
