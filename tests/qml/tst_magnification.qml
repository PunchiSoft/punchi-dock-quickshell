// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "DockMagnification"
    when: windowShown
    visible: true
    width: 840
    height: 280

    Component {
        id: fixture
        DockView { entries: DockFixtureModel {} }
    }
    Component {
        id: referenceWave
        DockMagnification {
            itemPitch: 72
            iconSize: 40
            itemSize: 40
            maximumScale: 1.65
            // Numeric profile samples use settled input; interaction tests below
            // retain real entry/exit durations and reversal coverage.
            enterDuration: 0
            leaveDuration: 0
            active: true
            progress: 1
            pointerX: 300
            activeIndex: 3
        }
    }
    SignalSpy { id: activation; signalName: "itemActivated" }

    function init() {
        failOnWarning(/.*/)
        mouseMove(test, 820, 140)
    }

    function createView() {
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        tryCompare(view, "itemCount", 8)
        verify(waitForRendering(view))
        return view
    }

    function tile(view, id) {
        const result = findChild(view, "launcher-" + id)
        verify(result !== null)
        return result
    }

    function test_referenceWaveProfileValues() {
        const wave = createTemporaryObject(referenceWave, test)
        verify(wave !== null)
        // Independent numeric samples for the revised common profile at icon=40,
        // pitch=72 and peak=1.65. They cover centre/shoulders, signed spacing,
        // cutoff and displacement beyond the seven-pitch support.
        const samples = [
            [0, 1.65, 0],
            [18, 1.6418515714590927, 6.337031429181852],
            [36, 1.617814882068286, 12.356297641365725],
            [72, 1.5276341856040885, 23.552683712081766],
            [144, 1.2526806964641979, 39.15898135344749],
            [198, 1.0709047681978903, 44.08190463604219],
            [252, 1, 45.5],
            [288, 1, 45.5]
        ]
        for (let i = 0; i < samples.length; ++i) {
            const sample = samples[i]
            fuzzyCompare(wave.scaleAt(300 + sample[0], 3), sample[1], 0.000001)
            fuzzyCompare(wave.scaleAt(300 - sample[0], 3), sample[1], 0.000001)
            fuzzyCompare(wave.shiftAt(300 + sample[0]), sample[2], 0.000001)
            fuzzyCompare(wave.shiftAt(300 - sample[0]), -sample[2], 0.000001)
        }
        wave.progress = 0.5
        tryCompare(wave, "progress", 0.5)
        fuzzyCompare(wave.scaleAt(300, 3), 1.325, 0.000001)
        fuzzyCompare(wave.shiftAt(498), 22.040952318021095, 0.000001)
    }

    function test_horizontalTrackingAndGapContinuity() {
        const view = createView()
        const kate = tile(view, "kate")
        const system = tile(view, "systemsettings")
        const origin = view.mapFromItem(kate, kate.width / 2, kate.height / 2)
        mouseMove(view, origin.x, origin.y)
        tryCompare(kate, "targetIconScale", view.maximumIconScale)
        mouseMove(view, origin.x, origin.y - 8)
        compare(kate.targetIconScale, view.maximumIconScale)
        let previous = kate.targetIconScale
        const pitch = view.itemSize + view.itemSpacing
        for (let x = 2; x <= pitch; x += 2) {
            mouseMove(view, origin.x + x, origin.y)
            verify(Math.abs(kate.targetIconScale - previous) < 0.04)
            previous = kate.targetIconScale
        }
        fuzzyCompare(system.targetIconScale, view.maximumIconScale, 0.001)
        verify(kate.targetIconScale > 1)
    }

    function test_highResolutionSourceStaysStableDuringZoom() {
        const view = createView()
        const kate = tile(view, "kate")
        const source = findChild(kate, "launcher-theme-icon")
        verify(source !== null)
        compare(kate.highQualityIconSize, 96)
        compare(source.width, 96)
        tryCompare(source, "valid", true)
        tryCompare(source, "status", Kirigami.Icon.Ready)
        fuzzyCompare(source.scale, 40 / 96, 0.000001)
        mouseMove(kate)
        tryCompare(kate, "targetIconScale", 2)
        compare(source.width, 96)
        fuzzyCompare(source.width * source.scale * kate.visualIconScale, 80, 0.000001)
        view.maximumIconScale = 3
        compare(kate.highQualityIconSize, 128)
        compare(source.width, 128)
        fuzzyCompare(source.scale, 40 / 128, 0.000001)
    }

    function test_balloonTracksIconAndTheme() {
        const view = createView()
        const kate = tile(view, "kate")
        const files = tile(view, "files")
        const tooltip = findChild(kate, "launcher-tooltip")
        verify(tooltip !== null)
        verify(view.focusItem(0))
        mouseMove(kate)
        tryCompare(tooltip, "opened", true)
        compare(tooltip.text, "Kate")
        fuzzyCompare(tooltip.x + tooltip.width / 2,
            kate.x + kate.width / 2 + kate.iconOffsetX, 0.01)
        fuzzyCompare(tooltip.y + tooltip.height + tooltip.metrics.gap,
            kate.y + kate.height / 2 + kate.iconOffsetY - kate.iconSize * kate.visualIconScale / 2, 0.01)
        const origin = view.mapFromItem(tooltip.parent, tooltip.x, tooltip.y)
        verify(origin.y >= 0)
        verify(files.activeFocus)
        compare(view.currentIndex, 0)
        view.palette.toolTipBase = "#203040"
        view.palette.toolTipText = "#f4f4f4"
        compare(tooltip.palette.toolTipBase, view.palette.toolTipBase)
        compare(tooltip.Kirigami.Theme.colorSet, Kirigami.Theme.Window)
        compare(tooltip.contentItem.color, tooltip.Kirigami.Theme.textColor)
        compare(tooltip.background.fillColor, tooltip.Kirigami.Theme.backgroundColor)
        verify(tooltip.background.tailHeight > 0)
        mouseMove(test, 820, 260)
        tryCompare(tooltip, "opened", false)
    }

    function test_highlightAndHitAreaFollowIcon() {
        const view = createView()
        const kate = tile(view, "kate")
        const highlight = findChild(kate, "launcher-highlight")
        verify(highlight !== null)
        activation.target = view
        activation.clear()
        mouseMove(kate)
        tryCompare(kate, "targetIconScale", 2)
        fuzzyCompare(kate.background.scale, kate.contentItem.scale, 0.000001)
        const frameCenter = view.mapFromItem(highlight, highlight.width / 2, highlight.height / 2)
        const iconCenter = view.mapFromItem(kate.contentItem,
            kate.contentItem.width / 2, kate.contentItem.height / 2)
        fuzzyCompare(frameCenter.x, iconCenter.x, 0.001)
        fuzzyCompare(frameCenter.y, iconCenter.y, 0.001)
        // Click inside the raised icon, above the original logical cell.
        const raisedPoint = view.mapFromItem(kate,
            kate.width / 2, kate.height / 2 - kate.iconSize / 2 + 3)
        mouseMove(view, raisedPoint.x, raisedPoint.y)
        tryCompare(kate, "hovered", true)
        mouseClick(view, raisedPoint.x, raisedPoint.y)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "kate")
    }

    function test_kdeExamples() {
        const view = createView()
        const ids = ["files", "terminal", "browser", "kate", "systemsettings",
                     "discover", "gwenview", "okular"]
        for (let i = 0; i < ids.length; ++i) {
            compare(view.entries.get(i).appId, ids[i])
            verify(tile(view, ids[i]).Accessible.name.length > 0)
        }
    }

    function test_waveNeighborsAndStableGeometry() {
        const view = createView()
        const center = tile(view, "kate")
        const left = tile(view, "browser")
        const right = tile(view, "systemsettings")
        const third = tile(view, "files")
        const far = tile(view, "okular")
        const width = view.width
        const height = view.height
        const x = center.x
        const leftX = left.x
        mouseMove(center, center.width / 2, center.height / 2)
        tryVerify(function() { return center.visualIconScale > 1.45 })
        tryCompare(center, "targetIconScale", view.maximumIconScale)
        verify(left.targetIconScale > 1)
        fuzzyCompare(left.targetIconScale, right.targetIconScale, 0.001)
        verify(left.targetIconScale < center.targetIconScale)
        verify(third.targetIconScale > 1)
        compare(far.targetIconScale, 1)
        compare(view.width, width)
        compare(view.height, height)
        compare(center.x, x)
        compare(left.x, leftX)
        compare(center.width, view.itemSize)
        fuzzyCompare(center.iconOffsetY, -center.iconSize * 0.5 * (center.visualIconScale - 1), 0.001)
        verify(left.iconOffsetX < 0)
        verify(right.iconOffsetX > 0)
        const mapped = view.mapFromItem(center.contentItem,
            center.contentItem.width / 2, center.contentItem.height / 2)
        verify(mapped.y - center.iconSize * center.visualIconScale / 2 >= 0)
        verify(mapped.y + center.iconSize * center.visualIconScale / 2 <= view.height)
        fuzzyCompare(center.scale, center.visualIconScale, 0.001)
    }

    function test_surfaceExpandsAndReturnsWithoutMovingCells() {
        const view = createView()
        const surface = findChild(view, "dock-surface")
        const kate = tile(view, "kate")
        verify(surface !== null)
        const baseWidth = surface.width
        const baseHeight = surface.height
        const cellX = kate.x
        const windowWidth = view.width
        const windowHeight = view.height
        mouseMove(kate)
        tryCompare(kate, "targetIconScale", 2)
        verify(surface.width > baseWidth)
        compare(surface.height, baseHeight)
        compare(kate.x, cellX)
        compare(view.width, windowWidth)
        compare(view.height, windowHeight)
        verify(surface.x >= 0 && surface.y >= 0)
        verify(surface.x + surface.width <= view.width)
        verify(surface.y + surface.height <= view.height)
        compare(surface.layer.samples, 8)
        const frame = kate.background
        compare(frame.layer.samples, 8)
        compare(frame.resolutionScale, kate.visualIconScale)
        const balloon = findChild(kate, "launcher-tooltip")
        compare(balloon.background.layer.samples, 8)
        // Both edge items must remain enclosed at the supported maximum.
        view.maximumIconScale = 3
        const edges = [tile(view, "files"), tile(view, "okular")]
        for (let i = 0; i < edges.length; ++i) {
            mouseMove(view, edges[i].x + edges[i].width / 2,
                edges[i].y + edges[i].height / 2)
            tryCompare(edges[i], "targetIconScale", 3)
            verify(surface.x >= 0 && surface.y >= 0)
            verify(surface.x + surface.width <= view.width)
            verify(surface.y + surface.height <= view.height)
        }
        view.maximumIconScale = 2
        mouseMove(test, 820, 270)
        tryCompare(surface, "width", baseWidth)
        tryCompare(surface, "height", baseHeight)
    }

    function test_reversalExitAndReentry() {
        const view = createView()
        const kate = tile(view, "kate")
        const okular = tile(view, "okular")
        mouseMove(kate)
        mouseMove(okular)
        mouseMove(kate)
        tryVerify(function() { return kate.visualIconScale > 1.45 })
        verify(kate.visualIconScale <= view.maximumIconScale)
        compare(okular.targetIconScale, 1)
        mouseMove(test, 820, 140)
        tryCompare(kate, "visualIconScale", 1)
        tryCompare(okular, "visualIconScale", 1)
        mouseMove(okular)
        tryVerify(function() { return okular.visualIconScale > 1.45 })
    }

    function test_reducedMotionAndDisabledWave() {
        const view = createView()
        verify(view.focusItem(0))
        const files = tile(view, "files")
        const kate = tile(view, "kate")
        mouseMove(kate)
        tryVerify(function() { return kate.visualIconScale > 1 })
        view.reducedMotion = true
        tryCompare(kate, "visualIconScale", 1.08)
        compare(kate.targetIconScale, 1.08)
        compare(kate.iconOffsetX, 0)
        verify(files.activeFocus)
        compare(view.currentIndex, 0)
        view.reducedMotion = false
        tryVerify(function() { return kate.visualIconScale > 1.45 })
        view.magnificationEnabled = false
        tryCompare(kate, "visualIconScale", 1)
        compare(kate.targetIconScale, 1)
        verify(files.activeFocus)
    }

    function test_magnifiedClickAndFocusSeparation() {
        const view = createView()
        activation.target = view
        activation.clear()
        verify(view.focusItem(0))
        const files = tile(view, "files")
        const kate = tile(view, "kate")
        mouseMove(kate)
        tryVerify(function() { return kate.visualIconScale > 1.45 })
        verify(files.activeFocus)
        compare(view.currentIndex, 0)
        mouseClick(kate)
        compare(activation.count, 1)
        compare(activation.signalArguments[0][0], "kate")
        compare(view.currentIndex, 3)
    }

    function test_liveBoundsAndResize() {
        const view = createView()
        const kate = tile(view, "kate")
        view.maximumIconScale = 4
        view.iconSize = 48
        mouseMove(kate)
        tryVerify(function() { return kate.visualIconScale > 1 })
        verify(kate.targetIconScale <= view.boundedIconScale)
        view.itemSize = 80
        verify(waitForRendering(view))
        mouseMove(kate)
        tryVerify(function() { return kate.visualIconScale > 1.5 })
        verify(kate.targetIconScale <= view.boundedIconScale)
        view.visible = false
        tryCompare(kate, "targetIconScale", 1)
        tryCompare(kate, "visualIconScale", 1)
    }
}
