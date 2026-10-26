// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/folders/FolderLayout.js" as FolderLayout

// The arrangement law is pure, so its cost model is checked without a scene.
TestCase {
    id: test
    name: "FolderLayout"

    function test_oneLineWinsWhenTheCellsFit(): void {
        // Four entries plus the open row are exactly one line of five cells.
        const arrangement = FolderLayout.arrangement(4, 5, 6)
        compare(arrangement.columns, 5)
        compare(arrangement.rows, 1)
        compare(arrangement.visibleRows, 1)
        compare(arrangement.scrollRequired, false)
    }
    function test_widerShapeWinsOverSquareGrid(): void {
        // Eighteen entries plus the open row: five columns leave two rows,
        // which is closer to the 1.5 shape than the square five-by-four.
        const arrangement = FolderLayout.arrangement(18, 5, 8)
        compare(arrangement.columns, 5)
        compare(arrangement.rows, 4)
        compare(arrangement.scrollRequired, false)
    }
    function test_overflowIsTheLastResort(): void {
        // Thirteen cells in a two-row surface: every candidate overflows, so the
        // widest grid wins and only whole rows stay visible.
        const arrangement = FolderLayout.arrangement(12, 5, 2)
        compare(arrangement.columns, 5)
        compare(arrangement.rows, 3)
        compare(arrangement.visibleRows, 2)
        compare(arrangement.scrollRequired, true)
    }
    function test_singleColumnCountsTheOpenRow(): void {
        const arrangement = FolderLayout.singleColumnArrangement(3, 2)
        compare(arrangement.columns, 1)
        compare(arrangement.rows, 4)
        compare(arrangement.visibleRows, 2)
        compare(arrangement.scrollRequired, true)
    }
    function test_ceilingFloorsGuardDegenerateInputs(): void {
        compare(FolderLayout.columnCeiling(0, 96), 1)
        compare(FolderLayout.columnCeiling(480, 96), 5)
        compare(FolderLayout.rowCeiling(0, 40), 1)
        compare(FolderLayout.rowCeiling(200, 40), 5)
        compare(FolderLayout.rowCeiling(200, 0), 1)
        compare(FolderLayout.arrangement(0, 5, 4).rows, 1)
    }
}
