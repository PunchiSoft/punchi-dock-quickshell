// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "PunchiFanGeometry.js" as PunchiFanGeometry

// Container fan: the entries of a container unfold from the dock icon as one arc,
// each row leaning a little more than the one before it. Only the rows paint:
// there is no card behind them, so the arc floats and the room a leaned pill
// needs is kept inside the popup instead of being clipped. The view owns the
// arc, the opening reveal, the closing row and the keyboard; the container owns
// the model and decides what an activation means.
Item {
    id: root

    // Entry rows: entryName and entryIcon, plus the description a caller may
    // publish. The fan consumes the same model as the Grid, List and Detail
    // presentations, so no row is mirrored in QML.
    property var contents: null
    property string dockEdge: "bottom"
    property int iconSize: 42
    property int rowLimit: 6
    // Height the popup can give the arc. Zero means it has no ceiling.
    property int maximumContentHeight: 0
    property bool showLabels: true
    property string fontFamily: Kirigami.Theme.defaultFont.family
    property int fontSize: Kirigami.Theme.defaultFont.pointSize
    property bool motionEnabled: true
    // Whether the surface that hosts the fan is on screen. Opening derives from
    // it, so the arc never plays while the popup is hidden.
    property bool opened: true
    property bool hasLocationAction: true
    property real revealSweepShare: 0.35
    property real rowArcStepDegrees: PunchiFanGeometry.rowArcStepDegrees
    // Exactly one row paints an emphasis band. Real pointer motion hands it to
    // the pointer; a keyboard focus move hands it back to the keyboard, so the
    // focused row and another hovered row never light up together.
    property bool pointerEmphasis: true
    property point lastPointerPosition: Qt.point(-1, -1)
    HoverHandler {
        onPointChanged: {
            const position = point.position
            if (position.x === root.lastPointerPosition.x
                    && position.y === root.lastPointerPosition.y) return
            root.lastPointerPosition = position
            root.pointerEmphasis = true
        }
    }
    // Window.activeFocusItem is typed as a bare item, so read the focus reason
    // through an untyped helper the linter can follow.
    function focusReasonOf(item): int {
        return item ? item["focusReason"] : Qt.OtherFocusReason
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const item = root.Window.activeFocusItem
            if (!item) return
            let ancestor = item
            while (ancestor && ancestor !== root) ancestor = ancestor.parent
            if (!ancestor) return
            const reason = root.focusReasonOf(item)
            root.pointerEmphasis = reason !== Qt.TabFocusReason
                && reason !== Qt.BacktabFocusReason && reason !== Qt.ShortcutFocusReason
        }
    }

    readonly property int entryCount: root.contents
        ? Math.max(0, Math.floor(Number(root.contents.count) || 0)) : 0

    signal activateRequested(int index)
    signal openLocationRequested()
    signal closeRequested()

    // The glyph beside the pill already says that the row opens the folder, so
    // the resting label stays the short action word the Grid uses for the same
    // row instead of a sentence the pill would have to cut.
    readonly property string openActionLabelText: qsTr("Open")

    readonly property int contentPadding: Kirigami.Units.smallSpacing
    readonly property int iconSpacing: Kirigami.Units.smallSpacing
    readonly property int labelHorizontalPadding: Kirigami.Units.smallSpacing * 2
    readonly property int labelRoundingMargin: 1
    readonly property int labelHeight: Math.max(
        labelMetrics.height + Kirigami.Units.smallSpacing * 2,
        Math.round(root.iconSize * 0.72))
    // Pitch of the reference, as a share of the icon: its rows are 64 px apart
    // for a 48 px icon, that is 1.33 icons.
    readonly property real rowPitchIconFactor: 1.33
    readonly property int rowHeight: Math.max(
        root.iconSize + Kirigami.Units.smallSpacing,
        Math.round(root.iconSize * root.rowPitchIconFactor),
        labelMetrics.height + Kirigami.Units.smallSpacing * 3)

    // Width of the widest name, measured on a hidden text so a single long entry
    // cannot widen the popup on its own. The probe is read imperatively: a model
    // row change cannot notify a binding, so the measurement is replayed when the
    // entry count changes and when the surface opens.
    property int measurementSerial: 0
    onEntryCountChanged: root.measurementSerial += 1
    onShowLabelsChanged: root.measurementSerial += 1
    function namesForProbe(): string {
        // Reading the serial is what makes this binding re-run when the
        // measurement is replayed.
        const serial = root.measurementSerial
        if (serial < 0) {
            return ""
        }
        const names = []
        const count = Math.min(root.entryCount, 128)
        for (let index = 0; index < count; ++index) {
            const entry = root.contents ? root.contents.get(index) : null
            const name = entry && entry.entryName ? String(entry.entryName) : ""
            if (name.length > 0) {
                names.push(name)
            }
        }
        if (root.hasLocationAction) {
            names.push(root.openActionLabelText)
        }
        return names.join("\n")
    }

    readonly property real maximumNaturalLabelWidth: root.showLabels
        ? Math.ceil(labelProbe.implicitWidth) + root.labelHorizontalPadding * 2
            + root.labelRoundingMargin : 0
    // Font-aware resting ceiling for a popup name: roughly ten wide glyphs plus
    // the pill padding. The full name stays in the model and the marquee reveals
    // it without changing this geometry.
    readonly property real maximumRestingLabelWidth: root.showLabels
        ? Math.ceil(restingMetrics.advanceWidth) + root.labelHorizontalPadding * 2
            + root.labelRoundingMargin : 0
    readonly property real maximumLabelWidth: Math.max(1, root.rowHeight * 2.2)
    readonly property real actionCaptionWidth: root.hasLocationAction && root.showLabels
        ? Math.ceil(actionProbe.implicitWidth) + root.labelHorizontalPadding * 2
            + root.labelRoundingMargin : 0
    // Width reserved for one name: the natural width of the widest entry, held
    // back to what one row may take, but never less than the closing row needs.
    readonly property real desiredLabelWidth: root.showLabels
        ? Math.max(root.actionCaptionWidth, Math.min(root.maximumNaturalLabelWidth,
            Math.min(root.maximumLabelWidth, root.maximumRestingLabelWidth))) : 0

    readonly property var rowMetrics: ({
        "iconSize": root.iconSize,
        "iconSpacing": root.iconSpacing,
        "labelWidth": root.desiredLabelWidth,
        "labelHeight": root.labelHeight,
        "rowHeight": root.rowHeight,
        "iconsOnRight": PunchiFanGeometry.iconsOnRight(root.dockEdge)
    })
    // The closing row is extra, not a stolen entry row: the container keeps the
    // entries its row limit allows and the action is added at the far end.
    readonly property int extraRowCount: root.hasLocationAction ? 1 : 0
    readonly property int visibleItemRows: PunchiFanGeometry.visibleRows(
        root.entryCount, root.rowLimit, root.maximumContentHeight,
        root.extraRowCount, root.dockEdge, root.rowMetrics)
    readonly property int displayedItemCount: Math.min(root.entryCount,
        root.visibleItemRows)
    readonly property int totalRowCount: root.displayedItemCount
        + root.extraRowCount
    readonly property var envelope: PunchiFanGeometry.envelopeForRows(
        root.totalRowCount, root.dockEdge, root.rowMetrics)
    readonly property int leadingOverhang: root.envelope.leading
    readonly property int trailingOverhang: root.envelope.trailing
    readonly property real requestedCurveAmplitude: PunchiFanGeometry.curveOffsetForDistance(
        1, root.totalRowCount, root.rowHeight)
    readonly property real curveAmplitude: Math.min(root.requestedCurveAmplitude,
        Math.max(0, root.width - root.iconSize - root.contentPadding * 2))
    readonly property real curveDirection: PunchiFanGeometry.curveDirection(root.dockEdge)
    readonly property bool iconsOnRight: PunchiFanGeometry.iconsOnRight(root.dockEdge)
    // The closing row sits at the far end of the arc, away from the panel.
    readonly property bool actionAtStart: root.hasLocationAction
        && (root.dockEdge === "bottom" || root.dockEdge === "left")
    readonly property int actionVisualIndex: root.actionAtStart ? 0
        : Math.max(0, root.totalRowCount - 1)
    readonly property real baseIconX: PunchiFanGeometry.isHorizontal(root.dockEdge)
        ? (root.iconsOnRight
            ? root.width - root.contentPadding - root.iconSize - root.curveAmplitude
            : root.contentPadding)
        : (root.iconsOnRight
            ? root.width - root.contentPadding - root.iconSize
            : root.contentPadding)
    readonly property real bandTop: root.leadingOverhang
        + (root.actionAtStart ? root.rowHeight : 0)

    implicitWidth: Math.ceil(root.contentPadding * 2 + root.desiredLabelWidth
        + (root.showLabels ? root.iconSpacing : 0) + root.iconSize
        + root.requestedCurveAmplitude)
    implicitHeight: root.leadingOverhang + root.totalRowCount * root.rowHeight
        + root.trailingOverhang

    // One opening progress owns the whole arc: every row derives its reveal from
    // it, and the Behavior retargets from the current value, so an interruption
    // continues instead of restarting.
    property real revealProgress: root.opened ? 1 : 0
    onOpenedChanged: {
        root.revealProgress = root.opened ? 1 : 0
        root.focusedOrder = -1
        if (root.opened) {
            root.measurementSerial += 1
        }
    }
    Behavior on revealProgress {
        enabled: root.motionEnabled && root.opened
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }
    readonly property real safeRevealProgress: root.motionEnabled
        ? PunchiFanGeometry.clamp(root.revealProgress, 0, 1) : 1

    function distanceFor(visualIndex: int): real {
        return PunchiFanGeometry.normalizedDistance(visualIndex, root.totalRowCount,
            root.dockEdge)
    }
    function leanFor(visualIndex: int): real {
        return PunchiFanGeometry.leanForIndex(visualIndex, root.totalRowCount,
            root.dockEdge, root.rowArcStepDegrees)
    }
    function curveFor(visualIndex: int): real {
        return PunchiFanGeometry.curveOffsetForIndex(visualIndex, root.totalRowCount,
            root.dockEdge, root.rowHeight)
    }
    function progressFor(visualIndex: int): real {
        return PunchiFanGeometry.revealProgressForDistance(root.distanceFor(visualIndex),
            root.safeRevealProgress, root.revealSweepShare)
    }
    // Travel from the anchor row to the row's own place, in row pitches. The
    // anchor is the dock icon: the row nearest the panel on a horizontal one and
    // the middle row on a vertical one.
    function travelSlideFor(visualIndex: int): real {
        return (PunchiFanGeometry.anchorIndex(root.totalRowCount, root.dockEdge)
            - visualIndex) * root.rowHeight
    }
    function iconXFor(visualIndex: int): real {
        return root.baseIconX + root.curveDirection * root.curveFor(visualIndex)
    }
    function curveSlideFor(visualIndex: int): real {
        return -root.curveDirection * root.curveFor(visualIndex)
    }

    TextMetrics {
        id: labelMetrics
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        font.weight: Font.DemiBold
        text: "Ag"
    }
    TextMetrics {
        id: restingMetrics
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        font.weight: Font.DemiBold
        text: "MMMMMMMMMM"
    }
    Text {
        id: labelProbe
        visible: false
        text: root.namesForProbe()
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        font.weight: Font.DemiBold
    }
    Text {
        id: actionProbe
        visible: false
        text: root.openActionLabelText
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        font.weight: Font.DemiBold
    }

    ListView {
        id: fanList
        objectName: "folderFanList"
        x: 0
        y: root.bandTop
        width: root.width
        height: root.displayedItemCount * root.rowHeight
        visible: root.displayedItemCount > 0
        enabled: visible
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        model: root.contents
        keyNavigationEnabled: false
        activeFocusOnTab: false
        currentIndex: -1

        delegate: PunchiFanRow {
            id: entryRow
            pointerEmphasis: root.pointerEmphasis

            required property int index
            required property string entryName
            required property string entryIcon

            readonly property int visualIndex: entryRow.index
                + (root.actionAtStart ? 1 : 0)

            objectName: "folderFanEntry-" + entryRow.index
            width: fanList.width
            height: root.rowHeight
            label: entryRow.entryName
            iconSource: entryRow.entryIcon
            iconX: root.iconXFor(entryRow.visualIndex)
            iconSize: root.iconSize
            rowLean: root.leanFor(entryRow.visualIndex)
                * root.progressFor(entryRow.visualIndex)
            curveSlide: root.curveSlideFor(entryRow.visualIndex)
            travelSlide: root.travelSlideFor(entryRow.visualIndex)
            progress: root.progressFor(entryRow.visualIndex)
            labelWidthCap: root.desiredLabelWidth
            labelHeight: root.labelHeight
            showLabels: root.showLabels
            iconsOnRight: root.iconsOnRight
            motionEnabled: root.motionEnabled
            contentPadding: root.contentPadding
            labelSpacing: root.iconSpacing
            itemIndex: entryRow.index
            itemCount: root.displayedItemCount

            onActivated: root.activateRequested(entryRow.index)
            onStepRequested: function(step) {
                root.stepFocus(entryRow.visualIndex, step)
            }
            onCloseRequested: root.closeRequested()
            onFocusReceived: root.focusedOrder = entryRow.visualIndex
        }
    }

    PunchiFanRow {
        id: actionRow
        objectName: "folderFanOpenLocation"
        pointerEmphasis: root.pointerEmphasis
        visible: root.hasLocationAction
        enabled: visible
        width: root.width
        height: root.rowHeight
        y: root.leadingOverhang
            + (root.actionAtStart ? 0 : root.displayedItemCount * root.rowHeight)
        label: root.openActionLabelText
        iconSource: "folder-open"
        locationAction: true
        iconX: root.iconXFor(root.actionVisualIndex)
        iconSize: root.iconSize
        rowLean: root.leanFor(root.actionVisualIndex)
            * root.progressFor(root.actionVisualIndex)
        curveSlide: root.curveSlideFor(root.actionVisualIndex)
        travelSlide: root.travelSlideFor(root.actionVisualIndex)
        progress: root.progressFor(root.actionVisualIndex)
        labelWidthCap: root.desiredLabelWidth
        labelHeight: root.labelHeight
        showLabels: root.showLabels
        iconsOnRight: root.iconsOnRight
        motionEnabled: root.motionEnabled
        contentPadding: root.contentPadding
        labelSpacing: root.iconSpacing

        onActivated: root.openLocationRequested()
        onStepRequested: function(step) {
            root.stepFocus(root.actionVisualIndex, step)
        }
        onCloseRequested: root.closeRequested()
        onFocusReceived: root.focusedOrder = root.actionVisualIndex
    }

    // Keyboard runs through the rows in the order they appear on screen, so the
    // closing row takes part in the same sequence as the entries.
    property int focusedOrder: -1
    onTotalRowCountChanged: if (root.focusedOrder >= root.totalRowCount)
        root.focusedOrder = -1
    function rowAt(order: int): Item {
        if (order < 0 || order >= root.totalRowCount) {
            return null
        }
        if (root.hasLocationAction && root.actionAtStart) {
            return order === 0 ? actionRow : fanList.itemAtIndex(order - 1)
        }
        if (root.hasLocationAction && order === root.totalRowCount - 1) {
            return actionRow
        }
        return fanList.itemAtIndex(order)
    }
    function focusOrder(order: int, reason): bool {
        if (reason === undefined) reason = Qt.MouseFocusReason
        const item = root.rowAt(order)
        if (!item || !item.visible || !item.enabled) {
            return false
        }
        root.focusedOrder = order
        item.forceActiveFocus(reason)
        return true
    }
    function stepFocus(from: int, step: int): void {
        const next = Math.max(0, Math.min(root.totalRowCount - 1, from + step))
        if (next !== from) {
            root.focusOrder(next, Qt.TabFocusReason)
        }
    }
    // Delegates are created while the scene renders, so the first attempt may
    // still find no row. Retrying a bounded number of times keeps the focus on
    // the arc without ever fighting a selection the user made meanwhile.
    property int focusAttempts: 0
    function requestInitialFocus(reason): void {
        if (reason === undefined) reason = Qt.MouseFocusReason
        root.focusAttempts = 0
        root.tryInitialFocus(reason)
    }
    function tryInitialFocus(reason): void {
        // A row that already holds the focus means the arc is settled: a pending
        // attempt must never pull the focus back from the user.
        if (!root.visible || root.totalRowCount <= 0 || root.focusedOrder >= 0) {
            return
        }
        const anchor = Math.round(PunchiFanGeometry.anchorIndex(root.totalRowCount,
            root.dockEdge))
        if (root.focusOrder(anchor, reason) || root.focusOrder(0, reason)) {
            return
        }
        if (++root.focusAttempts < 8) {
            Qt.callLater(function() { if (root) root.tryInitialFocus(reason) })
        }
    }
}
