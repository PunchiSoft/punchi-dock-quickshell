// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import org.kde.kirigami as Kirigami

// Qt Quick presentation of the top panel. The bar and its popups live here and
// know nothing about Quickshell windows, the menu controller or KDE adapters:
// the host injects the current time and the quick-controls facade, and this
// view only emits the intent the host forwards.
Item {
    id: root
    property date now: new Date()
    property var controls: null
    property bool reducedMotion: false
    property string screenName: ""
    readonly property int edgeMargin: Math.round(Kirigami.Units.smallSpacing * 1.5)
    readonly property int barHeight: Math.ceil(Kirigami.Units.gridUnit * 2
        + root.edgeMargin * 2)
    readonly property bool showLabels: root.width >= Kirigami.Units.gridUnit * 32
    readonly property bool showDate: root.width >= Kirigami.Units.gridUnit * 40
    readonly property string timeText: root.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
    readonly property string dateText: root.now.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    readonly property string clockText: root.showDate
        ? root.timeText + "  ·  " + root.dateText : root.timeText
    readonly property string clockAccessibleName: root.now.toLocaleString(Qt.locale(),
        Locale.LongFormat)
    readonly property var visiblePopup: quickControlsPopup.visible ? quickControlsPopup
        : calendarPopup.visible ? calendarPopup
        : menuPopup.visible ? menuPopup : null
    readonly property bool popupOpen: root.visiblePopup !== null
    // One rectangle for the host's input mask. The transparent panel surface
    // must not intercept the desktop outside the bar and the open popup.
    readonly property rect popupRegion: {
        const popup = root.visiblePopup
        if (!popup) return Qt.rect(0, 0, 0, 0)
        const left = Math.max(0, Math.floor(popup.x - root.edgeMargin))
        const top = Math.max(0, Math.floor(popup.y - root.edgeMargin))
        const right = Math.min(root.width, Math.ceil(popup.x + popup.width + root.edgeMargin))
        const bottom = Math.min(root.height, Math.ceil(popup.y + popup.height + root.edgeMargin))
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top))
    }
    implicitWidth: root.width
    implicitHeight: root.barHeight
    signal applicationsRequested()
    signal dockSettingsRequested()
    signal krunnerRequested()
    signal settingsModuleRequested(string module)
    signal bluetoothPairingRequested()
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    function closePopups(): void {
        menuPopup.close()
        quickControlsPopup.close()
        calendarPopup.close()
    }
    function openMenu(): void {
        root.closePopups()
        menuPopup.open()
    }
    function openQuickControls(): void {
        root.closePopups()
        quickControlsPopup.open()
    }
    function openCalendar(): void {
        root.closePopups()
        calendar.openCurrentMonth()
        calendarPopup.open()
    }
    function toggleMenu(): void {
        if (menuPopup.visible) menuPopup.close()
        else root.openMenu()
    }
    function toggleQuickControls(): void {
        if (quickControlsPopup.visible) quickControlsPopup.close()
        else root.openQuickControls()
    }
    function toggleCalendar(): void {
        if (calendarPopup.visible) calendarPopup.close()
        else root.openCalendar()
    }
    function focusFirst(): void { punchiButton.forceActiveFocus(Qt.TabFocusReason) }
    // The panel surface is a rounded bar inset from the screen edges; the
    // reserved height belongs to the host.
    Rectangle {
        id: barSurface
        objectName: "topBarSurface"
        x: root.edgeMargin
        y: root.edgeMargin
        width: Math.max(0, root.width - root.edgeMargin * 2)
        height: Math.max(0, root.barHeight - root.edgeMargin * 2)
        radius: Math.min(height / 2, Kirigami.Units.cornerRadius * 2)
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.12)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.mediumSpacing
            anchors.rightMargin: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.smallSpacing
            PunchiTopBarButton {
                id: punchiButton
                objectName: "punchiMenuButton"
                iconName: "start-here-kde"
                text: qsTr("Punchi")
                showLabel: root.showLabels
                selected: menuPopup.visible
                accessibleName: qsTr("Punchi menu")
                motionEnabled: !root.reducedMotion
                onClicked: root.toggleMenu()
            }
            Item { Layout.fillWidth: true }
            PunchiTopBarButton {
                objectName: "topBarSearch"
                iconName: "search"
                text: qsTr("Search")
                showLabel: false
                accessibleName: qsTr("Search with KRunner")
                motionEnabled: !root.reducedMotion
                onClicked: {
                    root.closePopups()
                    root.krunnerRequested()
                }
            }
            PunchiTopBarButton {
                id: quickControlsButton
                objectName: "topBarQuickControls"
                iconName: "settings-configure"
                text: qsTr("Quick controls")
                showLabel: false
                selected: quickControlsPopup.visible
                accessibleName: qsTr("Quick controls")
                motionEnabled: !root.reducedMotion
                onClicked: root.toggleQuickControls()
            }
            PunchiTopBarButton {
                id: clockButton
                objectName: "topBarClock"
                text: root.clockText
                showLabel: true
                selected: calendarPopup.visible
                accessibleName: root.clockAccessibleName
                motionEnabled: !root.reducedMotion
                onClicked: root.toggleCalendar()
            }
        }
    }
    PunchiTopBarPopup {
        id: menuPopup
        objectName: "topBarMenuPopup"
        parent: root
        anchorItem: punchiButton
        preferredWidth: Kirigami.Units.gridUnit * 12
        PunchiTopBarMenuContent {
            onApplicationsRequested: {
                root.closePopups()
                root.applicationsRequested()
            }
            onDockSettingsRequested: {
                root.closePopups()
                root.dockSettingsRequested()
            }
        }
    }
    PunchiTopBarPopup {
        id: quickControlsPopup
        objectName: "topBarQuickControlsPopup"
        parent: root
        anchorItem: quickControlsButton
        preferredWidth: Kirigami.Units.gridUnit * 21
        PunchiTopBarControlsCard {
            id: controlsCard
            controls: root.controls
            maximumHeight: quickControlsPopup.maximumContentHeight
            onBluetoothPairingRequested: root.bluetoothPairingRequested()
            onSettingsRequested: function(module) {
                root.closePopups()
                root.settingsModuleRequested(module)
            }
        }
    }
    PunchiTopBarPopup {
        id: calendarPopup
        objectName: "topBarCalendarPopup"
        parent: root
        anchorItem: clockButton
        preferredWidth: Kirigami.Units.gridUnit * 19
        PunchiTopBarCalendar {
            id: calendar
            now: root.now
        }
    }
}
