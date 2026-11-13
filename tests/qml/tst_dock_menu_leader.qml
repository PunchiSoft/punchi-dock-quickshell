// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/dock"

TestCase {
    id: test
    name: "DockMenuLeaderContext"
    when: windowShown
    visible: true
    width: 500
    height: 400

    Component {
        id: fixture
        PunchiDockContextContent {
            menuLeader: true
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
}
