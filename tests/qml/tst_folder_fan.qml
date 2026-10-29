// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import QtQml.Models
import "../../components"
import "../../components/PunchiFanGeometry.js" as PunchiFanGeometry

TestCase {
    id: test
    name: "FolderFan"
    when: windowShown
    visible: true
    width: 480
    height: 700

    // Owned model and spies, so each case can freely reconfigure its arc.
    Component {
        id: fixture
        Item {
            id: host
            property alias fan: fan
            property alias contents: contentsModel
            property alias launchSpy: launchSpy
            property alias openSpy: openSpy
            ListModel { id: contentsModel }
            PunchiFanView {
                id: fan
                x: 20
                y: 20
                width: 300
                height: implicitHeight
                motionEnabled: false
                opened: true
            }
            SignalSpy { id: launchSpy; target: fan; signalName: "activateRequested" }
            SignalSpy { id: openSpy; target: fan; signalName: "openLocationRequested" }
        }
    }

    function fillModel(model: ListModel, count: int): void {
        model.clear()
        for (let index = 0; index < count; ++index) {
            model.append({
                "entryName": "Entry " + index,
                "entryIcon": "text-plain",
                "directory": false,
                "description": "",
                "entryUrl": "file:///tmp/entry-" + index
            })
        }
    }

    // Every case starts from the default fan, so one case cannot inherit the
    // edge, limit or ceiling of the one before it.
    function prepare(host: var, count: int): void {
        host.launchSpy.clear()
        host.openSpy.clear()
        host.fan.dockEdge = "bottom"
        host.fan.rowLimit = 6
        host.fan.maximumContentHeight = 0
        host.fan.motionEnabled = false
        host.fan.opened = true
        fillModel(host.contents, count)
        host.fan.contents = host.contents
        tryCompare(host.fan, "entryCount", count)
        // The reserved width follows the theme font, which the scene resolves
        // while it renders, so wait for the measurement before asserting.
        tryVerify(function() { return host.fan.desiredLabelWidth > 0 })
    }

    function createFan(count: int): var {
        const host = createTemporaryObject(fixture, test)
        verify(host !== null)
        prepare(host, count)
        return host
    }

    function test_geometryFollowsTheArcLaw(): void {
        const host = createFan(5)
        const fan = host.fan
        compare(fan.dockEdge, "bottom")
        compare(fan.displayedItemCount, 5)
        compare(fan.totalRowCount, 6)
        verify(fan.actionAtStart)
        // The reserve the leaned pills need is content, not spare viewport: the
        // rows and the reserve add up to the surface.
        compare(fan.implicitHeight, fan.leadingOverhang
            + fan.totalRowCount * fan.rowHeight + fan.trailingOverhang)
        // Every row turns the way the arc opens, and the row that faces the
        // panel stands upright.
        verify(fan.leanFor(0) > fan.leanFor(1))
        verify(fan.leanFor(1) > fan.leanFor(2))
        compare(Math.abs(fan.leanFor(5)), 0)
        compare(fan.curveDirection, 1)
        verify(fan.curveFor(0) > fan.curveFor(1))
        compare(fan.curveFor(5), 0)
        compare(fan.iconsOnRight, true)
        host.destroy()
    }

    function test_envelopeReservesAPillThatLeavesItsBand(): void {
        // A pill that fits inside its row needs no reserve at all.
        const fitting = {"iconSize": 42, "iconSpacing": 5, "labelWidth": 58,
            "labelHeight": 30, "rowHeight": 56, "iconsOnRight": true}
        compare(PunchiFanGeometry.envelopeForRows(6, "bottom", fitting).leading, 0)
        compare(PunchiFanGeometry.envelopeForRows(6, "bottom", fitting).trailing, 0)
        // A tall pill on a short row leaves the band, and the reserve grows with
        // the far end of the arc, where the lean is largest.
        const leaning = {"iconSize": 40, "iconSpacing": 4, "labelWidth": 160,
            "labelHeight": 60, "rowHeight": 44, "iconsOnRight": true}
        verify(PunchiFanGeometry.envelopeForRows(6, "bottom", leaning).leading > 0)
        verify(PunchiFanGeometry.leanForIndex(0, 6, "bottom", 1.3)
            > PunchiFanGeometry.leanForIndex(1, 6, "bottom", 1.3))
        // The row that faces the panel stands upright on every edge.
        compare(Math.abs(PunchiFanGeometry.leanForIndex(5, 6, "bottom", 1.3)), 0)
        compare(Math.abs(PunchiFanGeometry.leanForIndex(0, 6, "top", 1.3)), 0)
        // The sweep settles the panel-facing row first.
        verify(PunchiFanGeometry.revealProgressForDistance(0, 0.5, 0.35)
            > PunchiFanGeometry.revealProgressForDistance(1, 0.5, 0.35))
    }

    function test_rowsBeyondTheLimitStayOutsideTheBand(): void {
        const host = createFan(3)
        const fan = host.fan
        const shownHeight = fan.implicitHeight
        prepare(host, 8)
        fan.rowLimit = 3
        compare(fan.displayedItemCount, 3)
        compare(fan.totalRowCount, 4)
        // The surface keeps the size of the rows it shows: the entries the limit
        // leaves out never grow the popup.
        compare(fan.implicitHeight, shownHeight)
        const list = findChild(fan, "folderFanList")
        verify(list !== null)
        compare(list.height, 3 * fan.rowHeight)
        // The model stays whole: the band clips the rows it does not show
        // instead of mirroring a sliced copy of the directory.
        compare(list.count, 8)
        tryVerify(function() {
            return findChild(fan, "folderFanEntry-2") !== null
        })
        host.destroy()
    }

    function test_heightCeilingShrinksTheBand(): void {
        const host = createFan(2)
        const fan = host.fan
        const ceiling = fan.implicitHeight
        prepare(host, 5)
        fan.maximumContentHeight = ceiling
        tryCompare(fan, "visibleItemRows", 2)
        verify(fan.implicitHeight <= ceiling)
        host.destroy()
    }

    function test_keyboardStepsThroughTheArcAndActivates(): void {
        const host = createFan(5)
        const fan = host.fan
        fan.requestInitialFocus()
        // The fan unfolds from the row nearest the panel: the last entry of a
        // bottom dock, because the closing row sits at the far end.
        tryVerify(function() { return fan.focusedOrder === fan.totalRowCount - 1 })
        const anchor = fan.rowAt(fan.focusedOrder)
        verify(anchor !== null)
        anchor.forceActiveFocus()
        keyClick(Qt.Key_Up)
        tryVerify(function() { return fan.focusedOrder === fan.totalRowCount - 2 })
        verify(fan.rowAt(fan.focusedOrder).activeFocus)
        keyClick(Qt.Key_Return)
        compare(host.launchSpy.count, 1)
        compare(host.launchSpy.signalArguments[0][0], 3)
        host.destroy()
    }

    function test_reducedMotionPresentsTheArcAtRest(): void {
        const host = createFan(5)
        const fan = host.fan
        compare(fan.safeRevealProgress, 1)
        let first = null
        tryVerify(function() {
            first = findChild(fan, "folderFanEntry-0")
            return first !== null
        })
        compare(first.progress, 1)
        compare(first.opacity, 1)
        compare(first.Accessible.name, "Entry 0")
        host.destroy()
    }

    function test_edgeChangesTheSideAndTheClosingRow(): void {
        const host = createFan(5)
        const fan = host.fan

        fan.dockEdge = "top"
        compare(fan.actionAtStart, false)
        compare(fan.iconsOnRight, true)
        compare(Math.abs(fan.leanFor(0)), 0)
        verify(fan.leanFor(fan.totalRowCount - 1) < 0)

        fan.dockEdge = "left"
        compare(fan.actionAtStart, true)
        compare(fan.iconsOnRight, false)
        compare(fan.baseIconX, fan.contentPadding)
        verify(fan.leanFor(0) > 0)
        verify(fan.leanFor(fan.totalRowCount - 1) < 0)

        fan.dockEdge = "right"
        compare(fan.actionAtStart, false)
        compare(fan.iconsOnRight, true)
        verify(fan.baseIconX > fan.width / 2)
        host.destroy()
    }

    function test_closingRowOpensTheContainer(): void {
        const host = createFan(5)
        const action = findChild(host.fan, "folderFanOpenLocation")
        verify(action !== null)
        verify(action.visible)
        compare(action.Accessible.name, "Open")
        mouseClick(action)
        compare(host.openSpy.count, 1)
        host.destroy()
    }

    function test_rowsOwnThePointingHandCursor(): void {
        const host = createFan(4)
        for (const name of ["folderFanEntry-0", "folderFanOpenLocation"]) {
            const row = findChild(host.fan, name)
            verify(row !== null, name)
            const handler = findChild(row, "folderFanCursor")
            verify(handler !== null, name)
            compare(handler.cursorShape, Qt.PointingHandCursor, name)
            compare(handler.enabled, row.enabled, name)
        }
        // The arc repeats the hand of the flat listings when the pointer is on a
        // row, not only when it is declared.
        const entry = findChild(host.fan, "folderFanEntry-0")
        const cursor = findChild(entry, "folderFanCursor")
        mouseMove(entry, entry.width / 2, entry.height / 2)
        tryCompare(cursor, "hovered", true)
        entry.enabled = false
        tryCompare(cursor, "enabled", false)
        tryCompare(cursor, "hovered", false)
        host.destroy()
    }
}
