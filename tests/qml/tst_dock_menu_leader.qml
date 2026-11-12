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
    height: 300

    Component {
        id: fixture
        PunchiDockContextContent {
            menuLeader: true
        }
    }

    function test_menuLeaderShowsOnlyOpenAndRemove() {
        const content = createTemporaryObject(fixture, test)
        verify(content !== null)
        const openAction = findChild(content, "openMenuAction")
        const removeAction = findChild(content, "removeMenuAction")
        const configureAction = findChild(content, "configureDockAction")
        verify(openAction !== null)
        verify(removeAction !== null)
        verify(configureAction !== null)
        compare(openAction.visible, true)
        compare(removeAction.visible, true)
        compare(configureAction.visible, false)
        let opened = 0
        let removed = 0
        content.openMenuRequested.connect(function() { opened++ })
        content.removeMenuRequested.connect(function() { removed++ })
        openAction.clicked()
        removeAction.clicked()
        compare(opened, 1)
        compare(removed, 1)
    }
}
