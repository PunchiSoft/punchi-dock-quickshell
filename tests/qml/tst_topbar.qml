// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtTest
import "../../config"
import "../../modules/topbar"

TestCase {
    id: test
    name: "TopBarView"
    when: windowShown
    width: 1280
    height: 800
    Component {
        id: fixture
        PunchiTopBarView {
            width: 1280
            height: 800
            now: new Date(2026, 10, 27, 18, 7)
        }
    }
    Component {
        id: narrowFixture
        PunchiTopBarView {
            width: 380
            height: 800
            now: new Date(2026, 10, 27, 18, 7)
        }
    }
    Component { id: calendarFixture; PunchiTopBarCalendar { now: new Date(2026, 10, 27, 18, 7) } }
    Component {
        id: reducedMotionFixture
        PunchiTopBarView {
            width: 1280
            height: 800
            reducedMotion: true
            now: new Date(2026, 10, 27, 18, 7)
        }
    }
    Component { id: spyComponent; SignalSpy {} }

    function test_barExposesEveryTriggerWithAnAccessibleName(): void {
        const view = createTemporaryObject(fixture, test)
        const menu = findChild(view, "punchiMenuButton")
        const search = findChild(view, "topBarSearch")
        const controls = findChild(view, "topBarQuickControls")
        const clock = findChild(view, "topBarClock")
        verify(menu !== null && search !== null && controls !== null && clock !== null)
        compare(menu.Accessible.name, "Punchi menu")
        compare(search.Accessible.name, "Search with KRunner")
        compare(controls.Accessible.name, "Quick controls")
        compare(clock.Accessible.name, view.now.toLocaleString(Qt.locale(), Locale.LongFormat))
        verify(view.barHeight > 0)
        compare(view.implicitHeight, view.barHeight)
    }
    function test_reducedMotionDisablesTheBarHoverFade(): void {
        const view = createTemporaryObject(fixture, test)
        verify(findChild(view, "punchiMenuButton").motionEnabled)
        const reduced = createTemporaryObject(reducedMotionFixture, test)
        compare(findChild(reduced, "punchiMenuButton").motionEnabled, false)
        compare(findChild(reduced, "topBarClock").motionEnabled, false)
    }
    function test_narrowBarKeepsActionsAndFullClockName(): void {
        const view = createTemporaryObject(narrowFixture, test)
        compare(view.showLabels, false)
        compare(view.showDate, false)
        const clock = findChild(view, "topBarClock")
        verify(clock !== null)
        compare(clock.text, view.timeText)
        // The date stays reachable through the accessible name.
        verify(clock.Accessible.name.length > view.timeText.length)
        verify(findChild(view, "topBarSearch") !== null)
        verify(findChild(view, "topBarQuickControls") !== null)
    }
    function test_menuPopupOpensAndRequestsTheFullscreenMenu(): void {
        const view = createTemporaryObject(fixture, test)
        const menuPopup = findChild(view, "topBarMenuPopup")
        verify(menuPopup !== null)
        const spy = createTemporaryObject(spyComponent, test)
        spy.target = view
        spy.signalName = "applicationsRequested"
        view.openMenu()
        tryCompare(menuPopup, "visible", true)
        const applications = findChild(view, "topBarApplications")
        verify(applications !== null)
        compare(applications.Accessible.name, "Applications")
        applications.clicked()
        compare(spy.count, 1)
        tryCompare(menuPopup, "visible", false)
    }
    function test_onlyOnePopupIsOpenAndEscapePolicyIsSet(): void {
        const view = createTemporaryObject(fixture, test)
        const menuPopup = findChild(view, "topBarMenuPopup")
        const calendarPopup = findChild(view, "topBarCalendarPopup")
        const controlsPopup = findChild(view, "topBarQuickControlsPopup")
        verify(menuPopup !== null && calendarPopup !== null && controlsPopup !== null)
        view.openMenu()
        tryCompare(menuPopup, "visible", true)
        view.openCalendar()
        tryCompare(menuPopup, "visible", false)
        tryCompare(calendarPopup, "visible", true)
        compare(calendarPopup.closePolicy & Popup.CloseOnEscape, Popup.CloseOnEscape)
        compare(calendarPopup.closePolicy & Popup.CloseOnPressOutside, Popup.CloseOnPressOutside)
        view.openQuickControls()
        tryCompare(calendarPopup, "visible", false)
        tryCompare(controlsPopup, "visible", true)
        view.closePopups()
        tryCompare(controlsPopup, "visible", false)
        compare(view.popupOpen, false)
    }
    function test_popupRegionStaysInsideThePanelWindow(): void {
        const view = createTemporaryObject(narrowFixture, test)
        const calendarPopup = findChild(view, "topBarCalendarPopup")
        verify(calendarPopup !== null)
        view.openCalendar()
        tryCompare(calendarPopup, "visible", true)
        verify(view.popupRegion.width > 0)
        verify(view.popupRegion.height > 0)
        verify(view.popupRegion.x >= 0)
        verify(view.popupRegion.x + view.popupRegion.width <= view.width)
        verify(view.popupRegion.y >= 0)
        verify(view.popupRegion.y + view.popupRegion.height <= view.height)
        const menuPopup = findChild(view, "topBarMenuPopup")
        verify(menuPopup !== null)
        view.openMenu()
        tryCompare(menuPopup, "visible", true)
        verify(menuPopup.x >= 0)
        verify(menuPopup.x + menuPopup.width <= view.width)
    }
    function test_calendarStartsOnTheCurrentMonthAndNavigates(): void {
        const calendar = createTemporaryObject(calendarFixture, test)
        compare(calendar.displayedYear, 2026)
        compare(calendar.displayedMonth, 10)
        calendar.openCurrentMonth()
        calendar.showNextMonth()
        compare(calendar.displayedMonth, 11)
        calendar.showNextMonth()
        compare(calendar.displayedYear, 2027)
        compare(calendar.displayedMonth, 0)
        calendar.showPreviousMonth()
        compare(calendar.displayedYear, 2026)
        compare(calendar.displayedMonth, 11)
        calendar.showPreviousMonth()
        compare(calendar.displayedMonth, 10)
        calendar.showNextMonth()
        calendar.openCurrentMonth()
        compare(calendar.displayedYear, 2026)
        compare(calendar.displayedMonth, 10)
        const monthLabel = findChild(calendar, "topBarCalendarMonth")
        verify(monthLabel !== null)
        verify(monthLabel.text.indexOf("noviembre") >= 0)
        calendar.locale = Qt.locale("en_US")
        verify(monthLabel.text.indexOf("November") >= 0)
        verify(findChild(calendar, "topBarCalendarGrid") !== null)
        compare(calendar.cells.length, 42)
        calendar.locale = Qt.locale("en_US")
        compare(calendar.locale.firstDayOfWeek % 7, 0)
        compare(calendar.cells[0].getDate(), 1)
        calendar.locale = Qt.locale("es_CL")
        compare(calendar.firstWeekday, calendar.locale.firstDayOfWeek % 7)
        compare(calendar.cells[0].getDate(), 26)
        compare(calendar.cells[0].getMonth(), 9)
        verify(findChild(calendar, "topBarCalendarToday") !== null)
    }
    function test_clockFollowsTheInjectedTime(): void {
        const view = createTemporaryObject(fixture, test)
        const clock = findChild(view, "topBarClock")
        verify(clock !== null)
        view.now = new Date(2026, 10, 27, 23, 59)
        compare(clock.text, view.timeText + "  ·  " + view.dateText)
        compare(view.showDate, true)
        verify(view.timeText.length > 0)
        verify(view.dateText.length > 0)
    }
}
