// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../components"
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "ApplicationActivation"
    when: windowShown
    visible: true
    width: 840
    height: 320
    property var samples: []

    Component {
        id: waveFixture
        PunchiDockView {
            entries: PunchiDockFixtureModel {}
            clickDuration: 30
        }
    }
    Component {
        id: bounceFixture
        PunchiTwoHopBounce {
            duration: 30
            onProgressChanged: test.samples.push(progress)
        }
    }
    Component {
        id: serviceFixture
        PunchiApplicationLaunchService { entries: PunchiDockFixtureModel {} }
    }
    QtObject {
        id: fakeAdapter
        property var calls: []
        property bool accepted: true
        function launch(desktopId: string): bool {
            calls = calls.concat([desktopId])
            return accepted
        }
    }
    SignalSpy { id: activated; signalName: "itemActivated" }
    SignalSpy { id: dispatched; signalName: "launchDispatched" }
    SignalSpy { id: rejected; signalName: "launchRejected" }

    function init() {
        failOnWarning(/.*/)
        samples = []
        fakeAdapter.calls = []
        fakeAdapter.accepted = true
        mouseMove(test, 830, 310)
    }

    function view() {
        const result = createTemporaryObject(waveFixture, test)
        verify(result !== null)
        verify(waitForRendering(result))
        activated.target = result
        activated.clear()
        return result
    }

    function test_defaultReferenceGeometry() {
        const dock = view()
        const settings = createTemporaryObject(Qt.createComponent("../../config/PunchiShellSettings.qml"), test)
        verify(settings !== null)
        compare(dock.iconSize, settings.iconSize)
        compare(dock.itemSize, settings.itemSize)
        compare(dock.itemSpacing, settings.spacing)
        compare(dock.padding, settings.padding)
        compare(dock.surfaceRadius, settings.surfaceRadius)
        compare(dock.background.height, dock.itemSize + dock.padding + dock.bottomContentPadding)
        compare(dock.background.width, dock.itemCount * dock.itemSize
            + (dock.itemCount - 1) * dock.itemSpacing + dock.padding * 2)
        const first = findChild(dock, "launcher-files")
        const next = findChild(dock, "launcher-terminal")
        compare(next.x - first.x, dock.itemSize + dock.itemSpacing)
        compare(first.x - dock.background.x, dock.padding)
        compare(first.y - dock.background.y, dock.padding)
    }

    function test_sourceTwoHopAndReset() {
        const bounce = createTemporaryObject(bounceFixture, test)
        bounce.play()
        verify(bounce.running)
        tryCompare(bounce, "running", false)
        compare(bounce.progress, 0)
        verify(samples.indexOf(1) >= 0)
        verify(samples.indexOf(0.8) > samples.indexOf(1))
        bounce.play()
        tryVerify(function() { return bounce.progress > 0 })
        bounce.reset()
        compare(bounce.running, false)
        compare(bounce.progress, 0)
    }

    function test_repeatedClicksKeepAllIntentsAndCoalesceMotion() {
        const dock = view()
        const tile = findChild(dock, "launcher-kate")
        dock.clickDuration = 100
        mouseMove(tile)
        tryCompare(tile, "targetIconScale", 2)
        tile.clicked()
        verify(tile.feedbackRunning)
        tryVerify(function() { return tile.clickOffsetY < -1 })
        const previousOffset = tile.clickOffsetY
        tile.clicked()
        compare(activated.count, 2)
        compare(tile.clickOffsetY, previousOffset)
        verify(tile.feedbackRunning)
        tryCompare(tile, "feedbackRunning", false)
        compare(tile.clickOffsetY, 0)
        compare(tile.targetIconScale, 2)
    }

    function test_consecutivePointerClicksOnDifferentLaunchers() {
        const dock = view()
        dock.clickDuration = 100
        const first = findChild(dock, "launcher-files")
        const second = findChild(dock, "launcher-kate")
        mouseMove(first)
        tryCompare(first, "targetIconScale", 2)
        mouseClick(first)
        compare(activated.count, 1)
        compare(activated.signalArguments[0][0], "files")
        verify(first.feedbackRunning)
        mouseMove(dock, second.x + second.width / 2, second.y + second.height / 2)
        tryCompare(second, "targetIconScale", 2)
        mouseClick(second)
        compare(activated.count, 2)
        compare(activated.signalArguments[1][0], "kate")
        verify(second.feedbackRunning)
        const third = findChild(dock, "launcher-gwenview")
        mouseMove(dock, third.x + third.width / 2, third.y + third.height / 2)
        tryCompare(third, "targetIconScale", 2)
        tryCompare(findChild(third, "launcher-tooltip"), "opened", true)
        mouseClick(third)
        compare(activated.count, 3)
        compare(activated.signalArguments[2][0], "gwenview")
    }

    function test_bounceFrameTooltipAndReservedBounds() {
        const dock = view()
        const tile = findChild(dock, "launcher-kate")
        const highlight = findChild(tile, "launcher-highlight")
        const balloon = findChild(tile, "launcher-tooltip")
        dock.clickDuration = 100
        mouseMove(tile)
        tryCompare(tile, "targetIconScale", 2)
        const height = dock.background.height
        tile.clicked()
        tryVerify(function() { return tile.clickOffsetY < -10 })
        const frameCenter = dock.mapFromItem(highlight, highlight.width / 2, highlight.height / 2)
        const iconCenter = dock.mapFromItem(tile.contentItem,
            tile.contentItem.width / 2, tile.contentItem.height / 2)
        fuzzyCompare(frameCenter.y, iconCenter.y, 0.001)
        verify(iconCenter.y - tile.height * tile.scale / 2 >= 0)
        verify(balloon.y >= 0)
        compare(dock.background.height, height)
        tryCompare(tile, "feedbackRunning", false)
    }

    function test_keyboardAndReducedMotionStillActivate() {
        const dock = view()
        const tile = findChild(dock, "launcher-files")
        verify(dock.focusItem(0))
        keyClick(Qt.Key_Return)
        compare(activated.count, 1)
        verify(tile.feedbackRunning)
        dock.reducedMotion = true
        compare(tile.feedbackRunning, false)
        compare(tile.clickOffsetY, 0)
        keyClick(Qt.Key_Space)
        compare(activated.count, 2)
        verify(!tile.feedbackRunning)
        compare(tile.clickOffsetY, 0)
    }

    function test_hideAndDisableReset() {
        const dock = view()
        const tile = findChild(dock, "launcher-kate")
        tile.clicked()
        verify(tile.feedbackRunning)
        dock.visible = false
        compare(tile.feedbackRunning, false)
        compare(tile.clickOffsetY, 0)
        dock.visible = true
        tile.clicked()
        verify(tile.feedbackRunning)
        dock.enabled = false
        compare(tile.feedbackRunning, false)
        compare(tile.clickOffsetY, 0)
    }

    function test_serviceExactIdsAndFailure() {
        const service = createTemporaryObject(serviceFixture, test, { adapter: fakeAdapter })
        dispatched.target = service
        rejected.target = service
        dispatched.clear()
        rejected.clear()
        const expected = ["org.kde.dolphin", "org.kde.konsole",
            "org.kde.kate", "systemsettings", "org.kde.discover", "org.kde.gwenview", "org.kde.okular"]
        let resolvedRoles = 0
        for (let i = 0; i < service.entries.count; ++i) {
            const entry = service.entries.get(i)
            // The Browser preset names a KDE MIME association, not a desktop
            // entry: the catalogue publishes the resolved id before the service
            // sees this model, so this raw catalogue has nothing to launch.
            if (entry.desktopId.length === 0) {
                compare(entry.appId, "browser")
                ++resolvedRoles
                continue
            }
            verify(service.launch(entry.appId))
        }
        compare(resolvedRoles, 1)
        compare(fakeAdapter.calls, expected)
        compare(dispatched.count, 7)
        verify(!service.launch("unconfigured; command"))
        compare(fakeAdapter.calls.length, 7)
        fakeAdapter.accepted = false
        verify(!service.launch("kate"))
        compare(rejected.count, 2)
        compare(dispatched.count, 7)
    }
}
