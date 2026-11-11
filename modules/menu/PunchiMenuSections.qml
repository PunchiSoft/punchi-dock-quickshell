// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Continuous application listing. Applications are grouped into the category
// sections the service prepared and the whole surface scrolls as one list, so a
// wheel, a touchpad or the keyboard lands on a row instead of a page boundary.
// The scroll gesture belongs to Kirigami's own handler, which applies the
// system's scroll lines and smooth-scroll preference.
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
    readonly property real cellWidth: Math.max(1,
        (root.availableWidth - Kirigami.Units.smallSpacing
            * (root.columnCount - 1)) / root.columnCount)
    // The reference draws the glyph at roughly 42% of the column pitch, so the
    // grid keeps its air on a large screen and still fits on a small one.
    readonly property int iconSize: Math.round(Math.max(Kirigami.Units.iconSizes.medium,
        Math.min(Kirigami.Units.iconSizes.enormous, root.cellWidth * 0.42))
        * root.safeIconScale)
    readonly property real labelHeight: root.showLabels
        ? Math.ceil(Kirigami.Units.gridUnit * 1.4) : 0
    readonly property real cellHeight: Math.max(Kirigami.Units.iconSizes.medium,
        root.iconSize + root.labelHeight + Kirigami.Units.smallSpacing * 4)
    readonly property real sectionSpacing: Kirigami.Units.largeSpacing
    readonly property real sectionHeaderHeight: Kirigami.Units.gridUnit * 1.6
    // The whole listing is measured here instead of read from the view, so a
    // keyboard selection can be revealed before its delegate exists.
    readonly property real listingHeight: {
        const sections = root.menuState ? root.menuState.sections : []
        let total = 0
        for (let index = 0; index < sections.length; ++index)
            total += root.sectionHeight(sections[index])
                + (index > 0 ? root.sectionSpacing : 0)
        return total
    }

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
    function sectionRows(section): int {
        const members = section ? section.members.length : 0
        return Math.max(1, Math.ceil(members / root.columnCount))
    }
    function sectionHeading(section): string {
        return root.categoryTitle(String(section ? section.categoryId || "" : ""))
    }
    function sectionHeight(section): real {
        const header = root.sectionHeading(section).length > 0
            ? root.sectionHeaderHeight : 0
        return header + root.sectionRows(section) * root.cellHeight
    }
    function takeKeyboardEmphasis(): void {
        root.pointerEmphasis = false
        root.revealCurrent()
    }
    // Scroll only as far as the selected cell needs to stay visible. A pointer
    // that moves over a cell does not scroll the list under itself.
    function revealCurrent(): void {
        const state = root.menuState
        if (!root.active || !state || state.currentIndex < 0) return
        const sections = state.sections
        if (!sections || sections.length === 0) return
        const position = state.sectionPosition(state.currentIndex)
        let top = 0
        for (let index = 0; index < position.section; ++index)
            top += root.sectionHeight(sections[index]) + root.sectionSpacing
        if (root.sectionHeading(sections[position.section]).length > 0)
            top += root.sectionHeaderHeight
        top += Math.floor(position.offset / root.columnCount) * root.cellHeight
        const bottom = top + root.cellHeight
        const viewTop = sectionList.contentY
        const viewBottom = viewTop + sectionList.height
        const maximum = Math.max(0, root.listingHeight - sectionList.height)
        if (top < viewTop)
            sectionList.contentY = Math.max(0, Math.min(maximum, top))
        else if (bottom > viewBottom)
            sectionList.contentY = Math.min(maximum, bottom - sectionList.height)
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
        model: root.menuState ? root.menuState.sections : []
        // The delegates reserve the scroll bar gutter themselves, so the column
        // width is stable while the policy changes.
        spacing: root.sectionSpacing
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The system decides how far one notch scrolls and whether the move is
        // smooth; intercepting the wheel would bypass the user's KDE setting.
        Kirigami.WheelHandler {
            objectName: "menuScrollWheel"
            target: sectionList
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: scrollBar
            objectName: "menuScrollBar"
            policy: root.showScrollBar
                ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        }

        footer: Item {
            width: sectionList.width
            height: Kirigami.Units.gridUnit * 1.5
        }

        delegate: Item {
            id: sectionDelegate
            required property var modelData
            required property int index

            readonly property var members: sectionDelegate.modelData.members || []
            readonly property string heading: root.sectionHeading(
                sectionDelegate.modelData)

            width: sectionList.width - root.scrollBarReserve
            height: root.sectionHeight(sectionDelegate.modelData)

            Item {
                id: headerRow
                width: parent.width
                height: root.sectionHeaderHeight
                visible: sectionDelegate.heading.length > 0
                Accessible.role: Accessible.Heading
                Accessible.name: sectionDelegate.heading

                Controls.Label {
                    id: headerLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: sectionDelegate.heading
                    textFormat: Text.PlainText
                    font.weight: Font.DemiBold
                }
                Kirigami.Separator {
                    anchors.left: headerLabel.right
                    anchors.right: parent.right
                    anchors.leftMargin: Kirigami.Units.smallSpacing
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Grid {
                id: sectionGrid
                anchors.top: sectionDelegate.heading.length > 0
                    ? headerRow.bottom : parent.top
                anchors.left: parent.left
                // The full grid width keeps every section's first cell on the
                // same column pitch, even when the section has one row only.
                width: root.availableWidth
                columns: root.columnCount
                rows: root.sectionRows(sectionDelegate.modelData)
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 0

                Repeater {
                    model: sectionDelegate.members

                    delegate: PunchiMenuTile {
                        required property var modelData
                        required property int index

                        readonly property int absoluteIndex:
                            sectionDelegate.modelData.start + index

                        width: root.cellWidth
                        height: root.cellHeight
                        title: String(modelData.name || modelData.title || "")
                        iconName: String(modelData.iconName || "")
                        showLabel: root.showLabels
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

    onActiveChanged: {
        if (!root.active) return
        sectionList.positionViewAtBeginning()
        root.revealCurrent()
    }

    Connections {
        target: root.menuState
        ignoreUnknownSignals: true
        function onCurrentIndexChanged() {
            if (!root.pointerEmphasis) root.revealCurrent()
        }
        // A new query or a different order replaces the listing; the surface
        // returns to its top instead of keeping an offset from the previous one.
        function onSectionsChanged() {
            sectionList.positionViewAtBeginning()
            if (!root.pointerEmphasis) root.revealCurrent()
        }
    }
}
