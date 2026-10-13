// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "DockWaveSpan"
    when: windowShown
    width: 1100
    height: 360
    visible: true
    Component {
        id: waveFixture
        DockMagnification {
            iconSize: 40
            itemSize: 44
            itemPitch: 46
            maximumScale: 2.5
            active: true
            pointerX: 0
            progress: 1
            enterDuration: 0
            leaveDuration: 0
        }
    }
    Component { id: viewFixture; DockView { entries: DockFixtureModel {} } }
    function init(): void {
        failOnWarning(/.*/)
        mouseMove(test, 1090, 350)
    }
    function test_thirdNeighboursAndFullZoomGrowth(): void {
        const wave = createTemporaryObject(waveFixture, test)
        let previous = Infinity
        for (let index = 0; index <= 4; ++index) {
            const scale = wave.scaleAt(index * wave.itemPitch, index)
            verify(scale <= previous)
            if (index <= 3) verify(scale > 1)
            else compare(scale, 1)
            fuzzyCompare(scale, wave.scaleAt(-index * wave.itemPitch, index), 0.000001)
            previous = scale
        }
        wave.maximumScale = 2
        const first = wave.scaleAt(wave.itemPitch, 1)
        const third = wave.scaleAt(wave.itemPitch * 3, 3)
        wave.maximumScale = 3
        verify(wave.scaleAt(wave.itemPitch, 1) > first)
        verify(wave.scaleAt(wave.itemPitch * 3, 3) > third)
        compare(wave.scaleAt(0, 0), 3)
    }
    function test_exactSpacingAcrossCursorZoomAndProgress(): void {
        const wave = createTemporaryObject(waveFixture, test)
        for (const extent of [24, 44, 64, 80]) {
            wave.itemSize = extent
            wave.iconSize = extent - 4
            wave.itemPitch = extent + 2
            for (const peak of [1, 2, 3, 6]) {
                wave.maximumScale = peak
                for (const progress of [0, 0.25, 0.75, 1]) {
                    wave.progress = progress
                    tryCompare(wave, "progress", progress)
                    for (let phase = 0; phase <= 20; ++phase) {
                        wave.pointerX = wave.itemPitch * phase / 20
                        for (let index = -5; index < 5; ++index) {
                            const left = wave.itemPitch * index
                            const right = left + wave.itemPitch
                            const gap = right + wave.shiftAt(right) - left - wave.shiftAt(left)
                                - wave.itemSize * (wave.scaleAt(left, index) + wave.scaleAt(right, index + 1)) / 2
                            // Preserve the real gap, not just a non-overlap tolerance.
                            fuzzyCompare(gap, 2, 0.000001)
                        }
                    }
                }
            }
        }
    }
    function test_supportBoundaryAndTransferRemainContinuous(): void {
        const wave = createTemporaryObject(waveFixture, test)
        const step = wave.itemPitch / 10000
        for (const boundary of [-wave.radius, -wave.itemPitch / 2, 0, wave.itemPitch / 2, wave.radius]) {
            const before = wave.shiftAt(boundary - step)
            const after = wave.shiftAt(boundary + step)
            verify(Math.abs(after - before) < wave.itemPitch / 1000)
            verify(Math.abs(wave.scaleAt(boundary - step, 0) - wave.scaleAt(boundary + step, 0)) < 0.001)
        }
        fuzzyCompare(wave.shiftAt(wave.radius * 3), wave.maximumShift, 0.000001)
        fuzzyCompare(wave.shiftAt(-wave.radius * 3), -wave.maximumShift, 0.000001)
        wave.maximumScale = NaN
        compare(wave.scaleAt(0, 0), 1)
        compare(wave.shiftAt(wave.itemPitch), 0)
        wave.reducedMotion = true
        compare(wave.scaleAt(0, 0), 1)
        wave.itemPitch = 0
        compare(wave.radius, 0)
        compare(wave.maximumShift, 0)
    }
    function test_themeCeilingAndRenderedBoundsForBaseSizes(): void {
        const view = createTemporaryObject(viewFixture, test)
        verify(waitForRendering(view))
        const center = findChild(view, "launcher-kate")
        const surface = findChild(view, "dock-surface")
        const themeBase = view.metrics.iconSize
        for (const base of [themeBase / 2, themeBase, themeBase * 1.5]) {
            view.iconSize = base
            view.itemSize = base + view.metrics.itemSize - themeBase
            view.maximumIconScale = 1
            compare(view.boundedIconScale, 1)
            view.maximumIconScale = 3
            fuzzyCompare(view.maximumIconSize, view.metrics.maximumMagnifiedIconSize, 0.000001)
            const peak = view.metrics.maximumMagnifiedIconSize / base
            fuzzyCompare(view.boundedIconScale, peak, 0.000001)
            verify(center.highQualityIconSize >= view.maximumIconSize)
            const width = view.width
            const height = view.height
            const backgroundHeight = surface.height
            for (const id of ["files", "kate", "okular"]) {
                const tile = findChild(view, "launcher-" + id)
                mouseMove(view, tile.x + tile.width / 2, tile.y + tile.height / 2)
                tryCompare(tile, "targetIconScale", peak)
                compare(view.width, width)
                compare(view.height, height)
                compare(surface.height, backgroundHeight)
                verify(surface.x >= 0 && surface.y >= 0)
                verify(surface.x + surface.width <= view.width + 0.001)
                verify(surface.y + surface.height <= view.height + 0.001)
                verify(tile.iconTopCenter.y >= 0)
                verify(tile.iconTopCenter.x - tile.iconSize * peak / 2 >= 0)
                verify(tile.iconTopCenter.x + tile.iconSize * peak / 2 <= view.width)
            }
            mouseMove(test, 1090, 350)
            tryCompare(center, "targetIconScale", 1)
        }
    }
}
