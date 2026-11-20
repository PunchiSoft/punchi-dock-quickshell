// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../../components"
import "../../config"

// Actions a PunchiMenu tile opens with the secondary button or the Menu key.
// It stays inside the fullscreen surface, so the menu keeps its own keyboard
// input and no second window is created per screen. The rows mirror the native
// launcher's application menu: the desktop entry's own actions, Places, Recent
// Files, a new window, the dock pin and the native menu editor. Only entries
// that KDE reports as available for this application are built.
Item {
    id: root
    objectName: "menuAppContext"
    property Item anchorItem: null
    property string applicationName: ""
    property var actions: []
    property var recentDocuments: null
    property var places: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool canPin: false
    property bool pinned: false
    property bool canEditApplication: false
    property bool motionEnabled: true
    property bool textShadow: true
    property point openedPoint: Qt.point(0, 0)

    readonly property PunchiPopupMetrics metrics: PunchiPopupMetrics {}
    readonly property int documentCount: root.recentDocuments
        ? (root.recentDocuments.count !== undefined
            ? root.recentDocuments.count : root.recentDocuments.length) : 0
    readonly property int placeCount: root.places
        ? (root.places.count !== undefined ? root.places.count
            : (root.places.items !== undefined ? root.places.items.length : 0)) : 0
    readonly property var placeItems: root.places && root.places.items !== undefined
        ? root.places.items : root.places
    readonly property int remainingPlaceCount: root.places
        && root.places.remainingCount !== undefined
        ? Number(root.places.remainingCount) : 0
    readonly property string placeGroup: root.places
        ? String(root.places.groupName || "") : ""
    readonly property real margin: Kirigami.Units.smallSpacing * 2
    readonly property real contentPadding: Kirigami.Units.smallSpacing * 2
    readonly property real tailHeight: Kirigami.Units.largeSpacing
    // A menu below the cell points up with the tail on its top edge; one above
    // the cell keeps the native bottom tail. The card adds that edge to its
    // measured content, so the body never covers the pointer.
    readonly property real scrollGutter: metrics.indicatorGutter
    readonly property real maximumCardWidth: Math.max(Kirigami.Units.gridUnit * 10,
        root.width - root.margin * 2)
    readonly property real maximumCardHeight: Math.max(Kirigami.Units.gridUnit * 10,
        root.height - root.margin * 2)
    readonly property real widestLabel: {
        let width = labelMetrics.advanceWidth(qsTr("Open"))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Open New Window")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Pin to Dock")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Unpin from Dock")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Edit Application…")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Recent Files")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Forget Recent Files")))
        width = Math.max(width, labelMetrics.advanceWidth(root.placeGroup.length > 0
            ? root.placeGroup : qsTr("Places")))
        width = Math.max(width, labelMetrics.advanceWidth(qsTr("Back to Places")))
        if (root.remainingPlaceCount > 0)
            width = Math.max(width, labelMetrics.advanceWidth(
                qsTr("%1 more Places…").arg(root.remainingPlaceCount)))
        for (let index = 0; index < root.actions.length; ++index)
            width = Math.max(width, labelMetrics.advanceWidth(
                String(root.actions[index].name || "")))
        return width
    }
    readonly property real cardWidth: Math.min(root.maximumCardWidth,
        Math.max(Kirigami.Units.gridUnit * 16, root.widestLabel
            + Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 7
            + root.contentPadding * 2))
    readonly property real cardHeight: Math.min(root.maximumCardHeight,
        column.implicitHeight + root.contentPadding * 2 + root.tailHeight)
    readonly property bool fitsBelow: root.openedPoint.y + Kirigami.Units.smallSpacing
        + card.height <= root.height - Kirigami.Units.smallSpacing
    readonly property bool tailAtTop: root.fitsBelow

    signal launchRequested()
    signal actionRequested(string actionId)
    signal newWindowRequested()
    signal placeRequested(string resource)
    signal morePlacesRequested()
    signal placesGroupRequested(string group)
    signal placesBackRequested()
    signal recentRequested(string resource)
    signal forgetRecentRequested()
    signal pinRequested()
    signal unpinRequested()
    signal editApplicationRequested()
    signal closed()

    anchors.fill: parent
    visible: false
    focus: visible
    z: 20
    Accessible.role: Accessible.PopupMenu
    Accessible.name: qsTr("Actions for %1").arg(root.applicationName)
    FontMetrics { id: labelMetrics; font: Kirigami.Theme.defaultFont }

    function openFor(anchor: Item, title: string, position: point): void {
        if (!anchor) return
        root.close(false)
        root.anchorItem = anchor
        root.applicationName = String(title || "")
        root.openedPoint = anchor.mapToItem(root, position.x, position.y)
        root.visible = true
        Qt.callLater(function() {
            if (root.visible) openRow.forceActiveFocus(Qt.MouseFocusReason)
        })
    }
    function close(restoreFocus): void {
        if (!root.visible) return
        root.visible = false
        root.anchorItem = null
        root.openedPoint = Qt.point(0, 0)
        if (restoreFocus !== false) root.closed()
    }
    // Up and Down walk the rows that are really visible, including the ones a
    // Repeater created, so keyboard use never falls into the hidden menu grid.
    function focusableRows(): var {
        const rows = []
        const children = column.children
        for (let index = 0; index < children.length; ++index) {
            const item = children[index]
            if (!item || !item.visible || !item.enabled) continue
            if (String(item.objectName).indexOf("contextRow") !== 0) continue
            if (typeof item.forceActiveFocus === "function") rows.push(item)
        }
        return rows
    }
    function moveFocus(delta: int): void {
        const rows = root.focusableRows()
        if (rows.length === 0) return
        let current = -1
        for (let index = 0; index < rows.length; ++index)
            if (rows[index].activeFocus) { current = index; break }
        const next = current < 0 ? 0 : Math.max(0, Math.min(rows.length - 1, current + delta))
        rows[next].forceActiveFocus(Qt.TabFocusReason)
    }

    Keys.onEscapePressed: root.close()
    Keys.onUpPressed: root.moveFocus(-1)
    Keys.onDownPressed: root.moveFocus(1)

    // A click outside the card closes only this menu, as the native launcher
    // does; the application grid stays open underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()
    }

    Item {
        id: card
        objectName: "menuAppContextCard"
        width: root.cardWidth
        height: root.cardHeight
        readonly property real gap: Kirigami.Units.smallSpacing
        // A balloon belongs under its pointer, so the tail lands on the cell
        // instead of at a corner. The clamp keeps a wide card on screen.
        readonly property real desiredX: root.openedPoint.x - width / 2
        // Placement is a binding, so a taller row set or a resized surface
        // flips the card without a second imperative measurement pass.
        x: Math.round(Math.max(gap,
            Math.min(root.width - width - gap, desiredX)))
        y: Math.round(Math.max(gap, Math.min(root.height - height - gap,
            root.tailAtTop ? root.openedPoint.y + gap
                : root.openedPoint.y - height - gap)))
        PunchiBalloonSurface {
            id: surface
            objectName: "menuAppContextSurface"
            anchors.fill: parent
            tailEdge: root.tailAtTop ? "top" : "bottom"
            tailHeight: root.tailHeight
            pointerX: Math.max(0, Math.min(width, root.openedPoint.x - card.x))
            cornerRadius: Kirigami.Units.cornerRadius * 2
        }
        ScrollView {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: root.contentPadding
            anchors.rightMargin: root.contentPadding
            anchors.topMargin: root.contentPadding + (root.tailAtTop ? root.tailHeight : 0)
            anchors.bottomMargin: root.contentPadding + (root.tailAtTop ? 0 : root.tailHeight)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: PunchiPopupScrollBar { motionEnabled: root.motionEnabled }
            ColumnLayout {
                id: column
                width: root.cardWidth - root.contentPadding * 2 - root.scrollGutter
                spacing: 0
                PunchiPopupActionRow {
                    id: openRow
                    objectName: "contextRowOpen"
                    Layout.fillWidth: true
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Open")
                    icon.name: "application-x-executable"
                    onClicked: root.launchRequested()
                }
                Repeater {
                    model: root.actions
                    delegate: PunchiPopupActionRow {
                        required property var modelData
                        objectName: "contextRowAction-" + modelData.actionId
                        Layout.fillWidth: true
                        motionEnabled: root.motionEnabled
                        textShadow: root.textShadow
                        marquee: true
                        text: String(modelData.name || "")
                        icon.name: String(modelData.icon || "system-run")
                        onClicked: root.actionRequested(String(modelData.actionId || ""))
                    }
                }
                PunchiPopupActionRow {
                    objectName: "contextRowNewWindow"
                    Layout.fillWidth: true
                    visible: root.canLaunchNewWindow
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Open New Window")
                    icon.name: "window-new"
                    onClicked: root.newWindowRequested()
                }
                PunchiPopupSeparator {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    visible: root.usesPlaces || root.documentCount > 0
                        || root.canPin || root.pinned || root.canEditApplication
                }
                PunchiPopupSectionHeader {
                    objectName: "contextHeaderPlaces"
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing / 2
                    visible: root.usesPlaces
                    textShadow: root.textShadow
                    text: root.placeGroup.length > 0 ? root.placeGroup : qsTr("Places")
                }
                PunchiPopupActionRow {
                    objectName: "contextRowPlacesBack"
                    Layout.fillWidth: true
                    visible: root.usesPlaces && root.placeGroup.length > 0
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Back to Places")
                    icon.name: "go-previous"
                    onClicked: root.placesBackRequested()
                }
                Repeater {
                    model: root.usesPlaces ? root.placeItems : []
                    delegate: PunchiPopupActionRow {
                        required property string resource
                        required property string name
                        required property string iconName
                        required property string groupName
                        required property bool isGroup
                        required property bool available
                        objectName: "contextRowPlace-" + resource
                        Layout.fillWidth: true
                        enabled: available
                        motionEnabled: root.motionEnabled
                        textShadow: root.textShadow
                        marquee: true
                        text: name
                        icon.name: iconName
                        submenu: isGroup
                        onClicked: {
                            if (isGroup) root.placesGroupRequested(groupName)
                            else root.placeRequested(resource)
                        }
                    }
                }
                PunchiPopupActionRow {
                    objectName: "contextRowMorePlaces"
                    Layout.fillWidth: true
                    visible: root.usesPlaces && root.remainingPlaceCount > 0
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("%1 more Places…").arg(root.remainingPlaceCount)
                    icon.name: "view-more-symbolic"
                    onClicked: root.morePlacesRequested()
                }
                PunchiPopupSectionHeader {
                    objectName: "contextHeaderRecent"
                    Layout.fillWidth: true
                    Layout.topMargin: root.usesPlaces ? Kirigami.Units.smallSpacing : 0
                    Layout.bottomMargin: Kirigami.Units.smallSpacing / 2
                    visible: root.documentCount > 0
                    textShadow: root.textShadow
                    text: qsTr("Recent Files")
                }
                Repeater {
                    model: root.documentCount > 0 ? root.recentDocuments : []
                    delegate: PunchiPopupActionRow {
                        required property string resource
                        required property string name
                        required property string iconName
                        objectName: "contextRowRecent-" + resource
                        Layout.fillWidth: true
                        motionEnabled: root.motionEnabled
                        textShadow: root.textShadow
                        marquee: true
                        text: name
                        icon.name: iconName
                        onClicked: root.recentRequested(resource)
                    }
                }
                PunchiPopupActionRow {
                    objectName: "contextRowForgetRecent"
                    Layout.fillWidth: true
                    visible: root.documentCount > 0
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Forget Recent Files")
                    icon.name: "edit-clear-history"
                    onClicked: root.forgetRecentRequested()
                }
                PunchiPopupActionRow {
                    objectName: "contextRowPin"
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.canPin
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Pin to Dock")
                    icon.name: "window-pin"
                    onClicked: root.pinRequested()
                }
                PunchiPopupActionRow {
                    objectName: "contextRowUnpin"
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: root.pinned
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Unpin from Dock")
                    icon.name: "window-unpin"
                    onClicked: root.unpinRequested()
                }
                PunchiPopupActionRow {
                    objectName: "contextRowEditApplication"
                    Layout.fillWidth: true
                    visible: root.canEditApplication
                    motionEnabled: root.motionEnabled
                    textShadow: root.textShadow
                    text: qsTr("Edit Application…")
                    icon.name: "kmenuedit"
                    onClicked: root.editApplicationRequested()
                }
            }
        }
    }
}
