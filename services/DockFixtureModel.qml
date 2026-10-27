// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQml.Models
import "../config/DefaultProfile.js" as DefaultProfile

// The first-run launcher catalog lives with the first-run profile, so adding an
// application to a fresh install is one data edit instead of two.
ListModel {
    Component.onCompleted: {
        for (const entry of DefaultProfile.launchers) append(entry)
    }
}
