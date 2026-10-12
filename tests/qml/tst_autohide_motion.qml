// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"
import "../../adapters/kde"
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

TestCase {
    id: test
    name: "PlasmaAutoHideMotion"
    when: windowShown
    visible: true
    width: 840
    height: 320
    Component { id: controller; DockVisibilityController { hideDelay: 1; transitionDuration: 120 } }
    Component { id: dock; DockView { entries: DockFixtureModel {} } }
    Component { id: nativeSensor; Native.AutoHideEdge {} }
    Component {
        id: reactiveSensor
        Native.AutoHideEdge {
            property bool requestedArmed: false
            // Exercise enabled -> armed dependency without opening a connection.
            enabled: false
            armed: !enabled && requestedArmed
        }
    }
    MotionPreferences { id: preferences }
    DockSlideGeometry { id: travelGeometry }
    function init() { failOnWarning(/.*/) }
    function test_themeDurationIsNotFloored() {
        compare(preferences.slideDuration, preferences.reducedMotion ? 0 : Kirigami.Units.longDuration)
    }
    function test_nativeTypeLoadsWithoutEnablingAConnection() {
        const sensor = createTemporaryObject(nativeSensor, test)
        verify(sensor)
        verify(!sensor.available)
        verify(!sensor.enabled)
        sensor.armed = true
        sensor.width = 480
        sensor.height = 4
        sensor.screenName = "TEST-1"
        verify(!sensor.available)
    }
    function test_armedBindingDoesNotInvalidateItsEnabledDependency() {
        const sensor = createTemporaryObject(reactiveSensor, test)
        verify(sensor)
        for (let i = 0; i < 4; ++i) {
            sensor.requestedArmed = true
            compare(sensor.armed, true)
            sensor.width += 1
            sensor.height += 1
            sensor.screenName = "TEST-" + i
            compare(sensor.armed, true)
            sensor.requestedArmed = false
            compare(sensor.armed, false)
            verify(!sensor.enabled)
        }
    }
    function test_repeatedReversalAndInstantFinalState() {
        const state = createTemporaryObject(controller, test)
        state.pointerInside = true
        state.autoHide = true
        for (let i = 0; i < 4; ++i) {
            state.pointerInside = false
            tryVerify(() => state.slideProgress > 0 && state.slideProgress < 1)
            const position = state.slideProgress
            state.pointerInside = true
            compare(state.slideProgress, position)
            verify(state.surfaceVisible)
            tryCompare(state, "slideProgress", 1)
        }
        state.pointerInside = false
        tryVerify(() => state.slideProgress < 1)
        state.transitionDuration = 0
        tryCompare(state, "surfaceVisible", false)
        compare(state.slideProgress, 0)
        state.menuOpen = true
        compare(state.slideProgress, 1)
        verify(state.surfaceVisible)
        state.autoHide = false
        state.menuOpen = false
        wait(10)
        verify(state.surfaceVisible)
    }
    function test_collapseFollowsProgressWithoutAnotherDurationDelay() {
        const state = createTemporaryObject(controller, test)
        state.autoHide = true
        tryCompare(state, "slideProgress", 0)
        // The completion is queued once; no second animation-budget timer.
        wait(0)
        compare(state.surfaceVisible, false)
        state.configuring = true
        verify(state.surfaceVisible)
        tryCompare(state, "slideProgress", 1)
    }
    function test_unusedHeadroomDoesNotLengthenTravel() {
        const view = createTemporaryObject(dock, test)
        waitForRendering(view)
        const travel = view.measureSlideTravelHeight()
        const bottomReserve = view.waveBottomReserve
        verify(travel < view.implicitHeight)
        const height = view.implicitHeight
        view.maximumIconScale = 3
        verify(view.implicitHeight > height)
        const restingTravel = travel + view.waveBottomReserve - bottomReserve
        compare(view.measureSlideTravelHeight(), restingTravel)
        const tile = view.children.find(c => c.appId === "files")
        verify(tile)
        tile.targetIconScale = 2
        verify(view.measureSlideTravelHeight() > restingTravel)
        tile.targetIconScale = 1
        compare(view.measureSlideTravelHeight(), restingTravel)
        tile.running = true
        compare(view.measureSlideTravelHeight(), restingTravel)
    }
    function test_geometryReversalKeepsCurrentPosition() {
        travelGeometry.capture(1, 80)
        compare(travelGeometry.distance, 80)
        const progress = 0.4
        const position = (1 - progress) * travelGeometry.distance
        travelGeometry.capture(progress, 130)
        compare((1 - progress) * travelGeometry.distance, position)
        travelGeometry.capture(0, 60)
        compare(travelGeometry.distance, 60)
        travelGeometry.capture(1, NaN)
        compare(travelGeometry.distance, 60)
    }
}
