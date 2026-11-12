// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Continuous application listing. The service prepares display rows (a heading
// row per named section and rows of at most `columns` applications), and this
// view creates one delegate per row. The delegate count therefore follows the
// viewport instead of the catalogue: a category with 500 applications never
// becomes 500 delegates. The wheel belongs to Kirigami's handler, which applies
// the system's scroll lines and smooth-scroll preference.
FocusScope {
    id: root

    required property var menuState
    property bool motionEnabled: true
    property bool showLabels: true
    // Off unless the profile enables it, matching the product default.
    property bool showScrollBar: false
    property real iconScale: 1.0
    property string hoverAnimation: "pulse"
    // Which modality owns the single band. The pointer owns it while it moves
    // over the surface; the next key press hands it back to the keyboard, so two
    // tiles never paint a band at the same time.
    property bool pointerEmphasis: true
    property point lastPointerPosition: Qt.point(-1, -1)
    // The surface states whether it is on screen, so an opening menu always
    // starts at the top and a closed one does not keep a stale position.
    property bool active: false

    readonly property bool measured: root.width > 1 && root.height > 1
        && root.cellWidth > 1 && root.cellHeight > 1
    readonly property int columnCount: root.menuState
        ? Math.max(1, root.menuState.columns) : 4
    readonly property real safeIconScale: {
        const requested = Number(root.iconScale)
        return Number.isFinite(requested) ? Math.max(0.75, Math.min(1.5, requested)) : 1.0
    }
    readonly property real scrollBarReserve: root.showScrollBar
        ? scrollBar.implicitWidth + Kirigami.Units.smallSpacing : 0
    readonly property real availableWidth: Math.max(1,
        sectionList.width - root.scrollBarReserve)
    readonly property real columnSpacing: Kirigami.Units.smallSpacing
    readonly property real cellWidth: Math.max(1,
        (root.availableWidth - root.columnSpacing
            * (root.columnCount - 1)) / root.columnCount)
    // The reference draws the glyph at roughly 42% of the column pitch, so the
    // grid keeps its air on a large screen and still fits on a small one.
    readonly property real desiredIconSize: Math.round(Math.max(Kirigami.Units.iconSizes.medium,
        Math.min(Kirigami.Units.iconSizes.enormous, root.cellWidth * 0.42))
        * root.safeIconScale)
    readonly property real labelHeight: root.showLabels
        ? Math.ceil(Kirigami.Units.gridUnit * 1.4) : 0
    // Calculate the preferred display-row capacity from icon, label and padding.
    readonly property real minimumCellHeight: Math.max(Kirigami.Units.iconSizes.medium,
        root.desiredIconSize + root.labelHeight + Kirigami.Units.smallSpacing * 4)
    readonly property bool hasCategoryHeaders: {
        const rows = root.menuState ? root.menuState.displayRows : []
        return rows && rows.some(row => row.kind === "header")
    }
    readonly property int visibleRows: Math.max(root.hasCategoryHeaders ? 2 : 1,
        Math.floor(root.height / root.minimumCellHeight))
    readonly property real cellHeight: Math.max(0, root.height / root.visibleRows)
    // Short displays retain a whole row by reducing its contents. Labels are
    // the first thing withheld; the icon never extends beyond its row.
    readonly property bool showCellLabels: root.showLabels
        && root.cellHeight >= root.minimumCellHeight
    readonly property real effectiveLabelHeight: root.showCellLabels ? root.labelHeight : 0
    readonly property int iconSize: root.cellHeight > 0
        ? Math.max(1, Math.min(root.desiredIconSize,
            root.cellHeight - root.effectiveLabelHeight - Kirigami.Units.smallSpacing * 4))
        : Math.max(1, Math.round(root.desiredIconSize))
    // The state owns the keyboard page step; keep it on the same whole rows
    // the viewport shows instead of a separate estimate.
    onVisibleRowsChanged: if (root.menuState) root.menuState.rows = root.visibleRows
    Component.onCompleted: if (root.menuState) root.menuState.rows = root.visibleRows
    readonly property real sectionHeaderHeight: Math.min(root.cellHeight,
        Kirigami.Units.gridUnit * 1.6)

    signal launchRequested(int index)

    function categoryTitle(categoryId: string): string {
        switch (String(categoryId || "")) {
        case "Network": return qsTr("Internet")
        case "Graphics": return qsTr("Graphics")
        case "AudioVideo": return qsTr("Multimedia")
        case "Office": return qsTr("Office")
        case "Development": return qsTr("Development")
        case "System": return qsTr("System")
        case "Utility": return qsTr("Utilities")
        case "Game": return qsTr("Games")
        case "Education": return qsTr("Education")
        case "Other": return qsTr("Other")
        default: return ""
        }
    }
    function rowHeight(row): real {
        // Headers occupy a display-row slot too, keeping every row boundary on
        // the same viewport grid in category and flat modes.
        return root.cellHeight
    }
    function rowTop(rowIndex: int): real {
        const rows = root.menuState ? root.menuState.displayRows : []
        let top = 0
        for (let row = 0; row < rowIndex && row < rows.length; ++row)
            top += root.rowHeight(rows[row])
        return top
    }
    function takeKeyboardEmphasis(): void {
        root.pointerEmphasis = false
        root.revealCurrent()
    }
    // The view knows the display row of the current cell, so revealing a
    // keyboard selection is one indexed call instead of measuring the content.
    function revealCurrent(): void {
        const state = root.menuState
        if (!root.active || !state || state.currentIndex < 0) return
        const row = state.displayRowFor(state.currentIndex)
        if (row >= 0) sectionList.positionViewAtIndex(row, ListView.Contain)
    }
    // A wheel gesture stops wherever the system delta leaves it, which can cut a
    // row through the middle. Once the gesture settles, move the list to the
    // nearest row boundary so a resting menu never shows half a cell.
    function scheduleSnap(): void {
        if (!root.active) return
        // A new gesture takes the list back from the settle animation instead
        // of letting the old target fight the wheel.
        snapAnimation.stop()
        snapTimer.restart()
    }
    function snapToRow(): void {
        const state = root.menuState
        if (!root.active || !state) return
        const rows = state.displayRows
        if (!rows || rows.length === 0) return
        const current = sectionList.contentY
        const maximum = Math.max(0, sectionList.contentHeight - sectionList.height)
        let top = 0
        let best = 0
        let bestDistance = Math.abs(current)
        for (let row = 0; row < rows.length; ++row) {
            const distance = Math.abs(top - current)
            if (distance < bestDistance) {
                best = top
                bestDistance = distance
            }
            top += root.rowHeight(rows[row])
            // Rows further than one cell away cannot be the nearest boundary.
            if (top > current + root.cellHeight) break
        }
        const target = Math.min(maximum, Math.max(0, best))
        if (Math.abs(target - current) < 0.5) return
        if (!root.motionEnabled) {
            snapAnimation.stop()
            sectionList.contentY = target
            return
        }
        snapAnimation.to = target
        snapAnimation.start()
    }

    HoverHandler {
        id: surfacePointer
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Applications grouped by category")

    Controls.Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Kirigami.Units.gridUnit
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: root.menuState && root.menuState.filtered.length === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: qsTr("No application matches your search")
        color: Kirigami.Theme.disabledTextColor
    }

    ListView {
        id: sectionList
        objectName: "menuSectionsView"
        anchors.fill: parent
        // Do not create delegates against a zero-sized viewport: a Label born
        // with zero width can keep its empty text texture after the cell grows.
        model: root.measured && root.menuState ? root.menuState.displayRows : []
        // One row of preload: the budget is the viewport plus one row, not a
        // section-sized cache.
        cacheBuffer: root.cellHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true
        // A drag or flick leaves the same partial row a wheel gesture does.
        onMovementEnded: root.scheduleSnap()
        // The system decides how far one notch scrolls and whether the move is
        // smooth; intercepting the wheel would bypass the user's KDE setting.
        Kirigami.WheelHandler {
            objectName: "menuScrollWheel"
            target: sectionList
            onWheel: root.scheduleSnap()
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: scrollBar
            objectName: "menuScrollBar"
            policy: root.showScrollBar
                ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        }

        footer: Item {
            width: sectionList.width
            // Keep the final legal scroll limit closer to the preceding row
            // boundary than the next one, so clamping cannot leave a partial row.
            height: Math.min(Kirigami.Units.gridUnit * 1.5, root.cellHeight * 0.4)
        }

        delegate: Item {
            id: displayRow
            objectName: "menuRowDelegate"
            required property var modelData
            required property int index

            readonly property bool isHeader: displayRow.modelData.kind === "header"
            readonly property string heading: displayRow.isHeader
                ? root.categoryTitle(String(displayRow.modelData.categoryId || ""))
                : ""

            width: sectionList.width - root.scrollBarReserve
            height: root.rowHeight(displayRow.modelData)

            Item {
                objectName: "menuSectionHeading"
                visible: displayRow.isHeader
                width: parent.width
                height: root.sectionHeaderHeight
                anchors.bottom: parent.bottom
                Accessible.role: Accessible.Heading
                Accessible.name: displayRow.heading

                Controls.Label {
                    id: headerLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: displayRow.heading
                    textFormat: Text.PlainText
                    font.weight: Font.DemiBold
                }
                Kirigami.Separator {
                    anchors.left: headerLabel.right
                    anchors.right: parent.right
                    anchors.leftMargin: root.columnSpacing
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                objectName: "menuDisplayRow"
                visible: !displayRow.isHeader
                width: parent.width
                height: root.cellHeight
                spacing: root.columnSpacing

                Repeater {
                    model: displayRow.isHeader ? [] : displayRow.modelData.members

                    delegate: PunchiMenuTile {
                        required property var modelData

                        readonly property int absoluteIndex: modelData.index

                        width: root.cellWidth
                        height: root.cellHeight
                        title: String(modelData.application.name
                            || modelData.application.title || "")
                        iconName: String(modelData.application.iconName || "")
                        showLabel: root.showCellLabels
                        motionEnabled: root.motionEnabled
                        hoverAnimation: root.hoverAnimation
                        iconSize: root.iconSize
                        selected: root.menuState
                            && root.menuState.currentIndex === absoluteIndex
                        // The surface owns the single band: without this the
                        // tile keeps its pointer default and the keyboard
                        // selection never paints.
                        pointerEmphasis: root.pointerEmphasis
                        onPointerEntered: {
                            if (root.menuState)
                                root.menuState.currentIndex = absoluteIndex
                        }
                        onActivated: root.launchRequested(absoluteIndex)
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: snapAnimation
        objectName: "menuSnapAnimation"
        target: sectionList
        property: "contentY"
        // A bounded settle with a known target; the theme duration keeps it
        // consistent with the rest of the shell instead of a custom 120 ms.
        duration: root.motionEnabled ? Kirigami.Units.longDuration : 0
        easing.type: Easing.OutCubic
    }
    Timer {
        id: snapTimer
        // Long enough to absorb a trackpad gesture, short enough that the list
        // still feels attached to the hand.
        interval: 300
        repeat: false
        onTriggered: root.snapToRow()
    }

    onActiveChanged: {
        if (!root.active) {
            snapTimer.stop()
            return
        }
        // The state reset belongs to the opening request. Taking the band for
        // the pointer and placing the view first keeps a stale selection from
        // revealing itself during the transition.
        root.pointerEmphasis = true
        sectionList.positionViewAtBeginning()
    }

    onMotionEnabledChanged: {
        if (!root.motionEnabled && snapAnimation.running) {
            const target = snapAnimation.to
            snapAnimation.stop()
            sectionList.contentY = target
        }
    }

    Connections {
        target: root.menuState
        ignoreUnknownSignals: true
        function onCurrentIndexChanged() {
            if (!root.pointerEmphasis) root.revealCurrent()
        }
        // A new query or a different order replaces the rows; the surface
        // returns to its top instead of keeping an offset from the previous one.
        function onDisplayRowsChanged() {
            sectionList.positionViewAtBeginning()
            if (!root.pointerEmphasis) root.revealCurrent()
        }
    }
}
