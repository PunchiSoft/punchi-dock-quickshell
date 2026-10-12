// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml

QtObject {
    property real distance: 1
    function capture(progress: real, extent: real): void {
        // Reversing a partially completed slide must keep its spatial trajectory.
        // Only settled endpoints can start a newly measured journey.
        if ((progress === 0 || progress === 1) && Number.isFinite(extent) && extent > 0)
            distance = Math.ceil(extent)
    }
}
