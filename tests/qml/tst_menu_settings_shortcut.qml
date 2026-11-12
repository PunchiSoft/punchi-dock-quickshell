// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/settings"
import "../../config"

TestCase {
    id: test
    name: "PunchiMenuSettingsShortcut"
    when: windowShown
    visible: true
    width: 700
    height: 700

    Component {
        id: fixture
        PunchiDockMenuSettings {
            width: 680
            pageActive: true
            settings: PunchiShellSettings { menuShortcut: "Meta" }
        }
    }

    function test_inlineEditorLoadsAndShowsTheSequence() {
        const page = createTemporaryObject(fixture, test)
        verify(page !== null)
        const editor = findChild(page, "menuShortcutEditor")
        verify(editor !== null)
        // qmllint disable missing-property unresolved-type
        compare(editor.keySequence.toString(), "Meta")
        // qmllint enable missing-property unresolved-type
        const help = findChild(page, "menuShortcutHelp")
        verify(help !== null)
        verify(help.text.length > 0)
    }
}
