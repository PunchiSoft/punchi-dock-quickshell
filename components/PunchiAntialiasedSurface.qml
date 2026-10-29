// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window

Item {
    id: root

    // Punchi Dock's Shaped/FlatThemeBackground resolve one shared MSAA layer.
    // Keep source resolution sufficient when an ancestor magnifies the surface.
    property real resolutionScale: 1
    layer.enabled: visible && width > 0 && height > 0
    layer.samples: 8
    layer.smooth: true
    layer.textureSize: Qt.size(
        Math.max(1, Math.ceil(width * Math.max(1, resolutionScale) * Screen.devicePixelRatio)),
        Math.max(1, Math.ceil(height * Math.max(1, resolutionScale) * Screen.devicePixelRatio)))
    Accessible.ignored: true
}
