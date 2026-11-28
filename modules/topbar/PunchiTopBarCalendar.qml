// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Monthly calendar of the clock popup. The viewed month starts at the current
// month when the popup opens and stays put while it remains open, even when the
// clock crosses midnight. Week start, weekday names and date text follow the
// system locale. The grid is a plain Qt Quick layout over Calendar-scale dates
// so its day data is explicit and testable.
ColumnLayout {
    id: root
    property date now: new Date()
    property var locale: Qt.locale()
    property int displayedYear: root.now.getFullYear()
    property int displayedMonth: root.now.getMonth()
    objectName: "topBarCalendar"
    readonly property int cellWidth: Math.floor(Kirigami.Units.gridUnit * 2.2)
    readonly property int cellHeight: Math.round(Kirigami.Units.gridUnit * 1.7)
    readonly property int calendarWidth: root.cellWidth * 7
    // Qt::DayOfWeek is 1..7 with Monday first; JavaScript Date.getDay() is
    // 0..6 with Sunday first.
    readonly property int firstWeekday: root.locale.firstDayOfWeek % 7
    readonly property date firstOfMonth: new Date(root.displayedYear, root.displayedMonth, 1)
    readonly property int leadingDays: (root.firstOfMonth.getDay() - root.firstWeekday + 7) % 7
    readonly property var cells: {
        const result = []
        const start = new Date(root.displayedYear, root.displayedMonth, 1 - root.leadingDays)
        for (let index = 0; index < 42; ++index)
            result.push(new Date(start.getFullYear(), start.getMonth(),
                start.getDate() + index))
        return result
    }
    spacing: Kirigami.Units.smallSpacing
    function focusFirst(): void { previous.forceActiveFocus(Qt.PopupFocusReason) }
    function openCurrentMonth(): void {
        root.displayedYear = root.now.getFullYear()
        root.displayedMonth = root.now.getMonth()
    }
    function showPreviousMonth(): void {
        if (root.displayedMonth === 0) {
            root.displayedMonth = 11
            root.displayedYear -= 1
        } else {
            root.displayedMonth -= 1
        }
    }
    function showNextMonth(): void {
        if (root.displayedMonth === 11) {
            root.displayedMonth = 0
            root.displayedYear += 1
        } else {
            root.displayedMonth += 1
        }
    }
    function isToday(date): bool {
        return date.getFullYear() === root.now.getFullYear()
            && date.getMonth() === root.now.getMonth()
            && date.getDate() === root.now.getDate()
    }
    RowLayout {
        Layout.fillWidth: true
        ToolButton {
            id: previous
            objectName: "topBarCalendarPrevious"
            icon.name: "go-previous"
            Accessible.name: qsTr("Previous month")
            onClicked: root.showPreviousMonth()
        }
        Label {
            objectName: "topBarCalendarMonth"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: new Date(root.displayedYear, root.displayedMonth, 1)
                .toLocaleDateString(root.locale, "MMMM yyyy")
            textFormat: Text.PlainText
            font.weight: Font.DemiBold
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
        }
        ToolButton {
            id: next
            objectName: "topBarCalendarNext"
            icon.name: "go-next"
            Accessible.name: qsTr("Next month")
            onClicked: root.showNextMonth()
        }
    }
    DayOfWeekRow {
        locale: root.locale
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.calendarWidth
        Layout.preferredHeight: root.cellHeight
    }
    Grid {
        id: grid
        objectName: "topBarCalendarGrid"
        Layout.alignment: Qt.AlignHCenter
        columns: 7
        spacing: 0
        Repeater {
            model: 42
            delegate: Item {
                id: cellItem
                required property int index
                readonly property date cellDate: root.cells[index]
                readonly property bool inMonth: cellDate.getMonth() === root.displayedMonth
                    && cellDate.getFullYear() === root.displayedYear
                readonly property bool today: root.isToday(cellDate)
                implicitWidth: root.cellWidth
                implicitHeight: root.cellHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    radius: width / 2
                    color: cellItem.today ? Kirigami.Theme.highlightColor : "transparent"
                    Accessible.ignored: true
                }
                Label {
                    anchors.centerIn: parent
                    text: cellItem.cellDate.getDate()
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    color: cellItem.today ? Kirigami.Theme.highlightedTextColor
                        : cellItem.inMonth ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }
            }
        }
    }
    Button {
        objectName: "topBarCalendarToday"
        Layout.fillWidth: true
        text: qsTr("Today")
        Accessible.name: text
        onClicked: root.openCurrentMonth()
    }
}
