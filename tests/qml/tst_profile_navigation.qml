// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config"
import "../../modules/settings"

TestCase {
    id: test
    name: "ProfileNavigation"
    when: windowShown
    width: 900
    height: 800
    Component {
        id: fixture
        PunchiSettingsWindow { settings: PunchiShellSettings {} }
    }

    function test_profileCategoryKeepsAboutAndFocusesImport() {
        const window = createTemporaryObject(fixture, test)
        verify(window !== null)
        window.open()
        tryCompare(window, "visible", true)
        const view = findChild(window.contentItem, "dockSettingsView")
        const profileButton = findChild(view, "profileSettingsPage")
        const aboutButton = findChild(view, "aboutSettingsPage")
        verify(profileButton !== null && aboutButton !== null)
        mouseClick(profileButton)
        tryCompare(view, "currentPage", 4)
        const page = findChild(view, "settingsDockProfile")
        verify(page !== null && page.visible)
        const importButton = findChild(view, "importDockProfile")
        tryCompare(importButton, "visible", true)
        view.focusFirst()
        tryCompare(importButton, "activeFocus", true)
        mouseClick(aboutButton)
        tryCompare(view, "currentPage", 3)
        window.close()
    }
}
