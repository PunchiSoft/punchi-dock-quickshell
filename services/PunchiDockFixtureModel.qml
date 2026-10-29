// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQml.Models
import "../config/PunchiDefaultProfile.js" as PunchiDefaultProfile

// The first-run launcher catalog lives with the first-run profile, so adding an
// application to a fresh install is one data edit instead of two.
ListModel {
    Component.onCompleted: {
        for (const entry of PunchiDefaultProfile.launchers) append(entry)
    }
}
