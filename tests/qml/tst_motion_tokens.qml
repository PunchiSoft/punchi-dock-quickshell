// SPDX-License-Identifier: GPL-3.0-or-later
// Guards the shared curve tokens: the six-number cubic-bezier contract and that
// a real NumberAnimation accepts a token array.
import QtQuick
import QtTest
import "../../config/PunchiMotion.js" as PunchiMotion

TestCase {
    name: "MotionTokens"

    QtObject { id: target; property real value: 0 }

    NumberAnimation {
        id: animation
        target: target
        property: "value"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.BezierSpline
        easing.bezierCurve: PunchiMotion.enter
    }

    function init(): void {
        failOnWarning(/.*/)
    }

    function test_curvesAreSixPointBeziers(): void {
        for (const name of ["enter", "exit", "move", "drawer", "ease"]) {
            const curve = PunchiMotion[name]
            compare(curve.length, 6, name + " must be one cubic bezier")
            compare(curve[4], 1, name + " must end at x=1")
            compare(curve[5], 1, name + " must end at y=1")
            for (let index = 0; index < 4; ++index)
                verify(curve[index] >= 0 && curve[index] <= 1,
                    name + " control point " + index + " is outside the unit square")
        }
    }

    function test_animationAcceptsTheCurve(): void {
        animation.start()
        wait(80)
        // The strong ease-out curve has covered most of the travel by 40% of the
        // duration; a rejected list would leave the value at its start.
        verify(target.value > 0.5, "the token curve did not animate the property")
        tryCompare(target, "value", 1, 2000)
    }
}
