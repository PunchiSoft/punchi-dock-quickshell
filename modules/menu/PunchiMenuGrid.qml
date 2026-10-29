// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Paged application grid. The page owns its slice of the listing, so a page
// change is a single animated move instead of a rebuild of every delegate, and
// the selection always resolves to a page that is on screen.
FocusScope {
    id: root

    required property var menuState
    property bool motionEnabled: true
    property bool showLabels: true
    property bool showPageArrows: true
    property real iconScale: 1.0
    property string hoverAnimation: "pulse"
    // Which modality owns the single band. The pointer owns it while it moves
    // over the surface; the next key press hands it back to the keyboard, so two
    // tiles never paint a band at the same time.
    property bool pointerEmphasis: true
    property point lastPointerPosition: Qt.point(-1, -1)
    // The surface states whether it is on screen. The page cache is only warmed
    // once the menu is actually visible, so the opening gesture never pays the
    // construction of the neighbouring pages.
    property bool active: false
    property real pagesCacheBuffer: 0

    readonly property int pageCapacity: root.menuState ? root.menuState.pageCapacity : 1
    readonly property int columnCount: root.menuState ? root.menuState.columns : 4
    readonly property int rowCount: root.menuState ? root.menuState.rows : 3
    readonly property real safeIconScale: {
        const requested = Number(root.iconScale)
        return Number.isFinite(requested) ? Math.max(0.75, Math.min(1.5, requested)) : 1.0
    }
    // The cell, not a fixed token, decides the glyph: the reference draws the icon
    // at roughly 54% of the row pitch and 42% of the column pitch, so the grid
    // keeps its air on a large screen and still fits on a small one.
    readonly property real cellWidth: Math.max(1, (root.pageWidth
        - Kirigami.Units.gridUnit * 2
        - Kirigami.Units.mediumSpacing * (root.columnCount - 1)) / root.columnCount)
    readonly property real cellHeight: Math.max(1, (pagesView.height
        - Kirigami.Units.smallSpacing * (root.rowCount - 1)) / root.rowCount)
    readonly property int iconSize: Math.round(Math.max(Kirigami.Units.iconSizes.medium,
        Math.min(Kirigami.Units.iconSizes.enormous,
            Math.min(root.cellHeight * 0.54, root.cellWidth * 0.42))) * root.safeIconScale)
    readonly property int pageCount: root.menuState ? root.menuState.pageCount : 1
    readonly property real pageWidth: Math.max(1, pagesView.width)

    signal launchRequested(int index)

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

    function takeKeyboardEmphasis(): void {
        root.pointerEmphasis = false
    }

    function syncPage(): void {
        if (!root.menuState) return
        const target = Math.max(0, Math.min(root.pageCount - 1, root.menuState.currentPage))
        if (pagesView.currentIndex !== target) pagesView.currentIndex = target
        const offset = target * root.pageWidth
        if (Math.abs(pagesView.contentX - offset) > 0.5) {
            if (root.motionEnabled) pagesView.positionViewAtIndex(target, ListView.Beginning)
            else {
                pagesView.highlightMoveDuration = 0
                pagesView.positionViewAtIndex(target, ListView.Beginning)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            Layout.fillWidth: true
            visible: root.menuState && root.menuState.filtered.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No application matches your search")
            color: Kirigami.Theme.disabledTextColor
        }

        ListView {
            id: pagesView
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            model: root.pageCount
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0
            highlightMoveDuration: root.motionEnabled ? Kirigami.Units.longDuration : 0
            interactive: root.pageCount > 1
            cacheBuffer: root.pagesCacheBuffer

            onMovementEnded: {
                const settled = Math.max(0, Math.min(root.pageCount - 1,
                    Math.round(contentX / root.pageWidth)))
                if (root.menuState) root.menuState.currentPage = settled
            }

            delegate: Item {
                id: pageDelegate
                required property int index

                width: pagesView.width
                height: pagesView.height

                readonly property int firstIndex: pageDelegate.index * root.pageCapacity

                Grid {
                    id: gridLayout
                    anchors.centerIn: parent
                    columns: root.columnCount
                    rows: root.rowCount
                    columnSpacing: Kirigami.Units.mediumSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.menuState
                            ? root.menuState.filtered.slice(pageDelegate.firstIndex,
                                pageDelegate.firstIndex + root.pageCapacity)
                            : []

                        delegate: PunchiMenuTile {
                            required property var modelData
                            required property int index

                            readonly property int absoluteIndex: pageDelegate.firstIndex + index

                            width: {
                                const raw = (pagesView.width - Kirigami.Units.gridUnit * 2
                                    - gridLayout.columnSpacing * (root.columnCount - 1))
                                    / Math.max(1, root.columnCount)
                                return Number.isFinite(raw) && raw > 1 ? raw : 1
                            }
                            height: {
                                const raw = (pagesView.height
                                    - gridLayout.rowSpacing * (root.rowCount - 1))
                                    / Math.max(1, root.rowCount)
                                return Number.isFinite(raw) && raw > 1 ? raw : 1
                            }
                            title: String(modelData.name || modelData.title || "")
                            iconName: String(modelData.iconName || "")
                            showLabel: root.showLabels
                            motionEnabled: root.motionEnabled
                            hoverAnimation: root.hoverAnimation
                            onPointerEntered: if (root.state) root.state.currentIndex = absoluteIndex
                            iconSize: root.iconSize
                            selected: root.menuState && root.menuState.currentIndex === absoluteIndex
                            onActivated: root.launchRequested(absoluteIndex)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showPageArrows && root.pageCount > 1
            spacing: Kirigami.Units.smallSpacing

            Controls.ToolButton {
                icon.name: "go-previous-symbolic"
                text: qsTr("Previous page")
                Accessible.name: qsTr("Previous page")
                enabled: root.menuState && root.menuState.currentPage > 0
                onClicked: root.menuState.selectPage(-1)
            }
            Controls.Label {
                text: root.menuState
                    ? qsTr("%1 of %2").arg(root.menuState.currentPage + 1).arg(root.pageCount) : ""
                color: Kirigami.Theme.textColor
            }
            Controls.ToolButton {
                icon.name: "go-next-symbolic"
                text: qsTr("Next page")
                Accessible.name: qsTr("Next page")
                enabled: root.menuState && root.menuState.currentPage < root.pageCount - 1
                onClicked: root.menuState.selectPage(1)
            }
        }
    }

    // One page of cache, restored after the first frame: paging stays immediate
    // while the open animation keeps the cost it had before.
    Timer {
        id: pageCacheWarmTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.active && root.pagesCacheBuffer < root.pageWidth)
                root.pagesCacheBuffer = root.pageWidth
        }
    }
    onActiveChanged: {
        if (!root.active) {
            pageCacheWarmTimer.stop()
            root.pagesCacheBuffer = 0
        } else if (root.pagesCacheBuffer < root.pageWidth) {
            pageCacheWarmTimer.restart()
        }
    }

    Connections {
        target: root.menuState
        ignoreUnknownSignals: true
        function onCurrentPageChanged() { root.syncPage() }
        function onPageCapacityChanged() { root.syncPage() }
    }
}
