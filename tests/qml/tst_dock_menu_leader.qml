// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/dock"

TestCase {
    id: test
    name: "DockMenuLeaderContext"
    when: windowShown
    visible: true
    width: 700
    height: 400

    Component {
        id: fixture
        PunchiDockContextContent {
            menuLeader: true
            // Loaded-settings stand-in: motion is allowed, so the marquee can
            // actually travel instead of falling back to the tooltip.
            settings: QtObject {
                property bool effectiveReducedMotion: false
                property bool fanSupported: true
                property bool magnificationEnabled: false
                property string panelMode: "always"
                property string dockEdge: "bottom"
            }
            applications: ListModel {
                id: applications
                ListElement {
                    appId: "alpha"
                    name: "Alpha"
                    title: "Alpha"
                    iconName: "application-x-executable"
                    installed: true
                }
                ListElement {
                    appId: "beta"
                    name: "Beta"
                    title: "Beta"
                    iconName: "application-x-executable"
                    installed: false
                }
                ListElement {
                    appId: "long"
                    name: "An application name far longer than the popup can ever show"
                    title: "An application name far longer than the popup can ever show"
                    iconName: "application-x-executable"
                    installed: true
                }
            }
        }
    }

    function test_menuLeaderListsInstalledAppsAndActions() {
        const content = createTemporaryObject(fixture, test)
        verify(content !== null)
        wait(50)
        const list = findChild(content, "menuLeaderApplications")
        const app = findChild(content, "menuApplication-alpha")
        const hiddenApp = findChild(content, "menuApplication-beta")
        const removeAction = findChild(content, "removeMenuAction")
        const showAction = findChild(content, "showMenuAction")
        const configureAction = findChild(content, "configureMenuAction")
        const configureDock = findChild(content, "configureDockAction")
        verify(list !== null)
        verify(app !== null)
        verify(hiddenApp === null)
        verify(removeAction !== null)
        verify(showAction !== null)
        verify(configureAction !== null)
        verify(configureDock !== null)
        compare(removeAction.visible, true)
        compare(showAction.visible, true)
        compare(configureAction.visible, true)
        compare(configureDock.visible, false)
        compare(findChild(content, "openMenuAction"), null)
        let launched = ""
        let opened = 0
        let removed = 0
        let configured = 0
        content.applicationRequested.connect(function(appId) { launched = appId })
        content.openMenuRequested.connect(function() { opened++ })
        content.removeMenuRequested.connect(function() { removed++ })
        content.settingsRequested.connect(function() { configured++ })
        app.clicked()
        removeAction.clicked()
        showAction.clicked()
        configureAction.clicked()
        compare(launched, "alpha")
        compare(opened, 1)
        compare(removed, 1)
        compare(configured, 1)
    }

    function test_menuLeaderWidthCapAndMarquee() {
        const content = createTemporaryObject(fixture, test)
        verify(content !== null)
        wait(50)
        // The list uses the same 24 grid-unit ceiling as the recent-files
        // section: a long application name cannot widen the balloon further.
        verify(content.implicitWidth
            <= Kirigami.Units.gridUnit * 24 + content.contentPadding * 2 + 0.5)
        const row = findChild(content, "menuApplication-long")
        verify(row !== null)
        const marquee = findChild(row, "popupRowMarqueeLabel")
        const plainLabel = findChild(row, "popupRowLabel")
        verify(marquee !== null)
        verify(plainLabel !== null)
        compare(marquee.visible, true)
        compare(plainLabel.visible, false)
        compare(marquee.overflowing, true)
        // The resting state clips; hovering reveals the full name with the
        // label carousel the menu already uses.
        compare(marquee.scrollOffset, 0)
        marquee.hovered = true
        tryCompare(marquee, "revealFullText", true)
        tryVerify(function() { return marquee.scrollOffset < -1 }, 5000)
    }

    function test_menuLeaderShortNameStaysAtRest() {
        const content = createTemporaryObject(fixture, test)
        verify(content !== null)
        wait(50)
        const row = findChild(content, "menuApplication-alpha")
        verify(row !== null)
        const marquee = findChild(row, "popupRowMarqueeLabel")
        verify(marquee !== null)
        compare(marquee.overflowing, false)
        compare(marquee.scrollOffset, 0)
    }
}
