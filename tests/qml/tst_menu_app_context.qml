// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/menu"
import "../../services"

TestCase {
    id: test
    name: "PunchiMenuAppContext"
    when: windowShown
    visible: true
    width: 700
    height: 480

    Component {
        id: fixture
        Window {
            id: viewport
            visible: true
            width: 700
            height: 480
            property alias context: menuContext
            PunchiMenuAppContext {
                id: menuContext
                anchors.fill: parent
            }
        }
    }
    Component {
        id: tileFixture
        Window {
            id: tileViewport
            visible: true
            width: 200
            height: 200
            property alias tile: menuTile
            PunchiMenuTile {
                id: menuTile
                anchors.fill: parent
                title: "Files"
                iconName: "system-file-manager"
                motionEnabled: false
            }
        }
    }
    Component {
        id: sectionsFixture
        Window {
            id: sectionsViewport
            visible: true
            width: 600
            height: 420
            property alias sections: sections
            property alias state: state
            property var catalogue: [
                {appId: "desktop:one.desktop", desktopId: "one.desktop",
                    name: "One", title: "One", iconName: "application-x-executable",
                    installed: true},
                {appId: "desktop:two.desktop", desktopId: "two.desktop",
                    name: "Two", title: "Two", iconName: "application-x-executable",
                    installed: true}
            ]
            PunchiMenuState {
                id: state
                applications: sectionsViewport.catalogue
                columns: 4
                rows: 3
            }
            PunchiMenuSections {
                id: sections
                anchors.fill: parent
                menuState: state
                active: true
                motionEnabled: false
                showLabels: true
            }
        }
    }

    function init() {
        failOnWarning(/.*/)
    }
    function open(context, point) {
        context.openFor(context.parent, "Files", point)
        tryCompare(context, "visible", true)
    }
    function row(context, name) {
        const item = findChild(context, name)
        verify(item !== null, "row " + name + " exists")
        return item
    }

    function test_rowsFollowTheApplicationCapabilities() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const context = viewport.context
        verify(waitForRendering(viewport.contentItem))
        open(context, Qt.point(100, 100))
        compare(row(context, "contextRowOpen").visible, true)
        compare(row(context, "contextRowNewWindow").visible, false)
        compare(row(context, "contextRowPin").visible, false)
        compare(row(context, "contextRowEditApplication").visible, false)

        context.canPin = true
        tryCompare(row(context, "contextRowPin"), "visible", true)
        context.pinned = true
        context.canPin = false
        tryCompare(row(context, "contextRowPin"), "visible", false)
        tryCompare(row(context, "contextRowUnpin"), "visible", true)

        context.canLaunchNewWindow = true
        tryCompare(row(context, "contextRowNewWindow"), "visible", true)
        context.canEditApplication = true
        tryCompare(row(context, "contextRowEditApplication"), "visible", true)

        const spy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "actionRequested" }', test)
        spy.target = context
        context.actions = [{actionId: "new-private", name: "New Private Window", icon: "window-new"}]
        const action = row(context, "contextRowAction-new-private")
        tryCompare(action, "visible", true)
        action.clicked()
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "new-private")
    }

    function test_recentFilesAndForgetStayInTheSurface() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const context = viewport.context
        verify(waitForRendering(viewport.contentItem))
        open(context, Qt.point(100, 100))
        const documents = createTemporaryQmlObject('import QtQuick; ListModel {}', test)
        documents.append({resource: "alpha", name: "Alpha document", iconName: "text-x-generic"})
        documents.append({resource: "beta", name: "Beta document", iconName: "text-x-generic"})
        context.recentDocuments = documents
        tryCompare(context, "documentCount", 2)
        const first = row(context, "contextRowRecent-alpha")
        tryCompare(first, "visible", true)
        compare(row(context, "contextRowForgetRecent").visible, true)
        compare(row(context, "contextHeaderRecent").visible, true)

        const recentSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "recentRequested" }', test)
        recentSpy.target = context
        first.clicked()
        compare(recentSpy.count, 1)
        compare(recentSpy.signalArguments[0][0], "alpha")

        const forgetSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "forgetRecentRequested" }', test)
        forgetSpy.target = context
        row(context, "contextRowForgetRecent").clicked()
        compare(forgetSpy.count, 1)

        documents.clear()
        tryCompare(context, "documentCount", 0)
        tryCompare(first, "visible", false)
        compare(row(context, "contextRowForgetRecent").visible, false)
    }

    function test_placesOpenGroupsAndMore() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const context = viewport.context
        verify(waitForRendering(viewport.contentItem))
        open(context, Qt.point(100, 100))
        const places = createTemporaryQmlObject(`import QtQuick; QtObject {
            property var items: [
                {resource: "file:///home", name: "Home", iconName: "folder-home",
                    groupName: "", isGroup: false, available: true},
                {resource: "remote", name: "Remote", iconName: "folder-remote",
                    groupName: "Remote", isGroup: true, available: true}]
            property int count: items.length
            property int remainingCount: 2
            property string groupName: ""
        }`, test)
        context.places = places
        context.usesPlaces = true
        tryCompare(context, "placeCount", 2)
        const home = row(context, "contextRowPlace-file:///home")
        tryCompare(home, "visible", true)
        compare(row(context, "contextRowMorePlaces").visible, true)
        compare(row(context, "contextRowPlacesBack").visible, false)

        const groupSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "placesGroupRequested" }', test)
        groupSpy.target = context
        row(context, "contextRowPlace-remote").clicked()
        compare(groupSpy.count, 1)
        compare(groupSpy.signalArguments[0][0], "Remote")

        const moreSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "morePlacesRequested" }', test)
        moreSpy.target = context
        row(context, "contextRowMorePlaces").clicked()
        compare(moreSpy.count, 1)

        places.groupName = "Remote"
        tryCompare(row(context, "contextRowPlacesBack"), "visible", true)
    }

    function test_openStaysInsideTheSurfaceAndCloses() {
        const viewport = createTemporaryObject(fixture, test)
        verify(viewport !== null)
        const context = viewport.context
        verify(waitForRendering(viewport.contentItem))
        const closed = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "closed" }', test)
        closed.target = context
        context.canPin = true

        open(context, Qt.point(690, 470))
        const card = row(context, "menuAppContextCard")
        const surface = row(context, "menuAppContextSurface")
        tryCompare(surface, "tailEdge", "bottom")
        verify(card.x >= 0)
        verify(card.y >= 0)
        verify(card.x + card.width <= context.width + 1)
        verify(card.y + card.height <= context.height + 1)
        // The card flips above the click instead of leaving the surface.
        verify(card.y < 470)
        // The click is near the surface edge, so the card clamps and the tail
        // follows the click as far as the rounded body allows.
        verify(surface.pointerX > surface.width * 0.8)
        verify(surface.pointerCenter < surface.width)

        keyClick(Qt.Key_Escape)
        tryCompare(context, "visible", false)
        compare(closed.count, 1)

        open(context, Qt.point(20, 20))
        tryCompare(surface, "tailEdge", "top")
        verify(surface.pointerX < surface.width * 0.2)
        verify(surface.pointerCenter > 0)
        mouseClick(context, 2, 2)
        tryCompare(context, "visible", false)
        compare(closed.count, 2)

        context.openFor(null, "Files", Qt.point(20, 20))
        compare(context.visible, false)
    }

    function test_secondaryButtonAsksForTheApplicationMenu() {
        const viewport = createTemporaryObject(tileFixture, test)
        verify(viewport !== null)
        verify(waitForRendering(viewport.contentItem))
        const tile = viewport.tile
        const contextSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "contextRequested" }', test)
        contextSpy.target = tile
        const activationSpy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "activated" }', test)
        activationSpy.target = tile

        mouseClick(tile, 30, 40, Qt.RightButton)
        compare(contextSpy.count, 1)
        compare(activationSpy.count, 0)
        const point = contextSpy.signalArguments[0][0]
        verify(Math.abs(point.x - 30) <= 1)
        verify(Math.abs(point.y - 40) <= 1)

        mouseClick(tile, 30, 40, Qt.LeftButton)
        compare(activationSpy.count, 1)
    }

    function test_menuKeyTargetsTheCurrentCell() {
        const viewport = createTemporaryObject(sectionsFixture, test)
        verify(viewport !== null)
        verify(waitForRendering(viewport.contentItem))
        const sections = viewport.sections
        const state = viewport.state
        tryCompare(sections, "measured", true)
        state.currentIndex = 0
        const spy = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "contextRequested" }', test)
        spy.target = sections
        sections.openContextForCurrent()
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 0)
        const point = spy.signalArguments[0][1]
        verify(point.x > 0)
        verify(point.y > 0)
        verify(point.x <= sections.width)
        verify(point.y <= sections.height)
    }
}
