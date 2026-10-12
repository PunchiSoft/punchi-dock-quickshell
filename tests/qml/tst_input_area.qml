// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "DockInputArea"
    when: windowShown
    visible: true
    width: 840
    height: 340
    SignalSpy { id: activated; signalName: "itemActivated" }
    Component { id: areaFixture; DockInputArea { hostWidth: 200; hostHeight: 340 } }
    Component {
        id: fixture
        Item {
            id: host
            x: 100
            y: test.height - height
            width: 600
            height: state.surfaceVisible ? 280 : 1
            property bool nativeSensor: false
            property alias visibilityState: state
            property alias area: area
            property alias view: view
            DockVisibilityController {
                id: state
                hideDelay: 40
                transitionDuration: 30
                pointerInside: area.hovered
            }
            DockInputArea {
                id: area
                hostWidth: host.width
                hostHeight: host.height
                contentBounds: Qt.rect(view.x + view.interactionBounds.x,
                    view.y + view.interactionBounds.y, view.interactionBounds.width,
                    view.interactionBounds.height)
                surfaceVisible: state.surfaceVisible
                nativeEdgeAvailable: host.nativeSensor
                enabled: state.edgeMode
                onEntered: state.reveal()
            }
            DockView {
                id: view
                entries: DockFixtureModel {}
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: metrics.edgeMargin
                height: implicitHeight
                visible: state.surfaceVisible
            }
        }
    }
    function init() {
        failOnWarning(/.*/)
        mouseMove(test, 10, 10)
    }
    function test_stationaryEdgeGapHoldsReveal_data() {
        return [
            {tag: "auto-fallback", dodge: false, native: false, instant: false},
            {tag: "dodge-fallback", dodge: true, native: false, instant: false},
            {tag: "auto-native-handoff", dodge: false, native: true, instant: false},
            {tag: "dodge-native-handoff", dodge: true, native: true, instant: false},
            {tag: "auto-reduced", dodge: false, native: false, instant: true},
            {tag: "dodge-reduced", dodge: true, native: false, instant: true}
        ]
    }
    function test_stationaryEdgeGapHoldsReveal(data) {
        const host = createTemporaryObject(fixture, test, {nativeSensor: data.native})
        host.visibilityState.reducedMotion = data.instant
        host.visibilityState.autoHide = !data.dodge
        host.visibilityState.dodgeWindows = data.dodge
        host.visibilityState.overlapAvailable = true
        host.visibilityState.overlapping = true
        tryCompare(host.visibilityState, "surfaceVisible", false)
        // The pointer stays at the same scene position as the host expands up.
        mouseMove(test, host.x + host.width / 2, test.height - 1)
        if (data.native) host.visibilityState.reveal() // Native signal; no compositor here.
        tryCompare(host.visibilityState, "surfaceVisible", true)
        tryCompare(host.area, "hovered", true)
        tryCompare(host.visibilityState, "slideProgress", 1)
        verify(host.area.y + host.area.height === host.height)
        verify(host.view.y + host.view.height < host.height)
        wait(180) // More than four leave-grace intervals, without mouse motion.
        verify(host.visibilityState.revealed)
        verify(host.visibilityState.surfaceVisible)
        compare(host.visibilityState.slideProgress, 1)
        // Crossing only the visual bottom margin must still hold, without zoom.
        mouseMove(host, host.width / 2, host.height - host.view.metrics.edgeMargin / 2)
        wait(100)
        verify(host.visibilityState.revealed)
        // Actually leaving the input rectangle releases the hold normally.
        mouseMove(test, host.x - 10, test.height - 1)
        tryCompare(host.area, "hovered", false)
        tryCompare(host.visibilityState, "surfaceVisible", false)
    }
    function test_inputGeometryRemainsIndependentOfZoomAndSlide() {
        const host = createTemporaryObject(fixture, test)
        host.visibilityState.configuring = true
        host.visibilityState.autoHide = true
        const bounds = Qt.rect(host.area.x, host.area.y, host.area.width, host.area.height)
        host.view.maximumIconScale = 3
        compare(host.area.y + host.area.height, host.height)
        host.view.maximumIconScale = 2
        compare(Qt.rect(host.area.x, host.area.y, host.area.width, host.area.height), bounds)
        host.visibilityState.slideProgress = 0.4
        compare(Qt.rect(host.area.x, host.area.y, host.area.width, host.area.height), bounds)
        host.nativeSensor = true
        host.visibilityState.surfaceVisible = false
        compare(host.area.width, 0)
    }
    function test_unusedHeadroomAndSidesDoNotHoldOrMagnify() {
        const host = createTemporaryObject(fixture, test)
        host.visibilityState.configuring = true
        host.visibilityState.autoHide = true
        verify(waitForRendering(host))
        verify(host.area.y > host.view.y)
        verify(host.area.x > 0)
        mouseMove(host, host.width / 2, host.view.y + 1)
        tryCompare(host.area, "hovered", false)
        wait(150)
        const tile = findChild(host.view, "launcher-kate")
        compare(tile.visualIconScale, 1)
        host.visibilityState.configuring = false
        tryCompare(host.visibilityState, "surfaceVisible", false)
    }
    function test_ancestorObserverIsOwnedByItsInputArea() {
        const area = createTemporaryObject(areaFixture, test)
        mouseMove(test, 100, 320)
        tryCompare(area, "hovered", true)
        area.destroy()
        wait(0)
        mouseMove(test, 100, 300)
        const replacement = createTemporaryObject(areaFixture, test)
        mouseMove(test, 100, 320)
        tryCompare(replacement, "hovered", true)
    }
    function test_raisedIconTargetsKeepInputWithoutExtendingToTooltipAllocation() {
        const host = createTemporaryObject(fixture, test)
        verify(waitForRendering(host))
        host.visibilityState.autoHide = true
        const tile = findChild(host.view, "launcher-kate")
        activated.target = host.view
        activated.clear()
        mouseMove(tile)
        tryCompare(host.area, "hovered", true)
        tryCompare(tile, "targetIconScale", 2)
        const top = tile.iconTopCenter.y
        verify(top < host.view.surfaceBounds.y)
        mouseMove(host.view, tile.iconTopCenter.x, top + 2)
        tryCompare(host.area, "hovered", true)
        wait(180)
        verify(host.visibilityState.surfaceVisible)
        verify(host.area.y > host.view.y)
        mouseClick(tile)
        compare(activated.count, 1)
        compare(activated.signalArguments[0][0], "kate")
        verify(host.visibilityState.surfaceVisible)
    }
}
