// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../components"

TestCase {
    id: test
    name: "PopupRowHighlight"
    when: windowShown
    width: 200
    height: 100

    PopupRowHighlight {
        id: highlight
        width: 120
        height: 40
        hoverOpacity: 0.3
        pressedOpacity: 1
        focusRingWidth: 1
    }
    property real peakScale: 0
    Connections {
        target: highlight
        function onMotionScaleChanged() {
            test.peakScale = Math.max(test.peakScale, highlight.motionScale)
        }
    }

    function init() {
        highlight.hovered = false
        highlight.pressed = false
        highlight.stopScaleAnimations()
        highlight.motionScale = 1
        highlight.pressScale = 1
        highlight.motionEnabled = true
        test.peakScale = 0
    }

    function test_reducedMotionKeepsFinalStateWithoutScaling() {
        highlight.motionEnabled = false
        highlight.hovered = true
        compare(highlight.motionScale, 1)
        compare(highlight.visualScale, 1)
        fuzzyCompare(highlight.color.a, 0.3, 0.001)
        highlight.pressed = true
        fuzzyCompare(highlight.pressScale, 0.97, 0.001)
        highlight.pressed = false
        compare(highlight.pressScale, 1)
        highlight.hovered = false
        fuzzyCompare(highlight.color.a, 0, 0.001)
    }

    function test_hoverPulsesAndReturnsToRest() {
        highlight.hovered = true
        wait(400)
        verify(test.peakScale > 1.02, "hover never pulsed: " + test.peakScale)
        fuzzyCompare(test.peakScale, 1.03, 0.001)
        fuzzyCompare(highlight.motionScale, 1, 0.001)
    }

    function test_interruptionSettlesAtRest() {
        highlight.hovered = true
        wait(80)
        verify(highlight.motionScale > 1)
        highlight.hovered = false
        wait(250)
        fuzzyCompare(highlight.motionScale, 1, 0.001)
    }

    function test_pressAnimatesInsideTheSameSurface() {
        highlight.pressed = true
        wait(80)
        fuzzyCompare(highlight.pressScale, 0.97, 0.005)
        highlight.pressed = false
        wait(80)
        fuzzyCompare(highlight.pressScale, 1, 0.005)
    }
}
