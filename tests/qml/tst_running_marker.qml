// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "RunningMarker"
    when: windowShown
    visible: true
    width: 900
    height: 400
    Component {
        id: fixture
        DockView {
            entries: DockFixtureModel {}
            reducedMotion: true
            applicationState: QtObject {
                property int revision: 0
                property string runningId: "files"
                function isRunning(id: string): bool { return id === runningId }
                onRunningIdChanged: revision++
            }
        }
    }
    function init(): void { failOnWarning(/.*/) }
    function test_markerFollowsStateAndHorizontalWaveOnly(): void {
        const dock = createTemporaryObject(fixture, test)
        verify(waitForRendering(dock))
        const files = findChild(dock, "launcher-files")
        const terminal = findChild(dock, "launcher-terminal")
        verify(files.running)
        verify(!terminal.running)
        const marker = findChild(dock, "launcher-running-marker-files")
        verify(marker.visible, JSON.stringify({running: files.running, tileVisible: files.visible,
            dockVisible: dock.visible, markerVisible: marker.visible, markerParent: marker.parent.objectName}))
        compare(marker.parent, dock)
        const diameter = marker.width
        const baseline = marker.y
        mouseMove(files)
        verify(files.visualIconScale > 1)
        compare(marker.width, diameter)
        compare(marker.y, baseline)
        fuzzyCompare(marker.x + marker.width / 2, files.x + files.width / 2 + files.iconOffsetX, 0.001)
        mouseClick(terminal)
        verify(!terminal.running)
        verify(files.running)
        dock.applicationState.runningId = "terminal"
        compare(files.running, false)
        compare(terminal.running, true)
        dock.applicationState.runningId = ""
        compare(terminal.running, false)
        dock.entries.remove(0)
        tryCompare(dock, "itemCount", 7)
        compare(findChild(dock, "launcher-running-marker-files"), null)
    }
}
