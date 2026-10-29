// SPDX-License-Identifier: GPL-3.0-or-later
import QtTest
import "../../modules/dock"

TestCase {
    name: "DockWindowAllocation"
    PunchiDockWindowGeometry { id: geometry }
    function test_screenMetricsAndEdgeFallbacks() {
        geometry.baseHeight = 166
        geometry.screenHeight = 1080
        geometry.bottomMargin = 4
        compare(geometry.windowHeight, 1076)
        geometry.bottomMargin = 0
        compare(geometry.windowHeight, 1080)
        geometry.screenHeight = 0
        compare(geometry.windowHeight, 166)
        geometry.screenHeight = NaN
        compare(geometry.windowHeight, 166)
        geometry.screenHeight = 720
        geometry.bottomMargin = -4
        compare(geometry.windowHeight, 720)
        geometry.surfaceVisible = false
        geometry.edgeHeight = 1.5
        compare(geometry.windowHeight, 2)
        geometry.edgeHeight = NaN
        compare(geometry.windowHeight, 1)
        geometry.surfaceVisible = true
        compare(geometry.windowHeight, 720)
    }
}
