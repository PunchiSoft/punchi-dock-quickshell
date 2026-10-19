// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/dock"

TestCase {
    id: test
    name: "ContextPointerAndKeyboardFocus"
    when: windowShown
    Component {
        id: fixture
        Window {
            visible: true
            width: 500
            height: 500
            property alias content: content
            DockContextContent { id: content; pinned: true }
        }
    }
    function init() { failOnWarning(/.*/) }
    function test_pointerHoverDoesNotFillPopupFocus() {
        const viewport = createTemporaryObject(fixture, test)
        const content = viewport.content
        verify(waitForRendering(content))
        content.focusFirst()
        const configure = findChild(content, "configureDockAction")
        const unpin = findChild(content, "unpinDockAction")
        tryCompare(configure, "activeFocus", true)
        mouseMove(unpin, unpin.width / 2, unpin.height / 2)
        tryCompare(unpin, "hovered", true)
        compare(configure.background.color.a, 0)
        verify(unpin.background.color.a > 0)
        fuzzyCompare(unpin.background.color.a, 0.3, 0.001)
        compare(unpin.background.border.color, Kirigami.Theme.focusColor)
        compare(unpin.background.border.width, 1)
        compare(configure.background.border.width, 0)
        // Keyboard focus remains explicit and actionable, independently of hover.
        keyClick(Qt.Key_Backtab)
        keyClick(Qt.Key_Tab)
        tryCompare(configure, "visualFocus", true)
        verify(configure.background.border.width > 0)
        verify(configure.background.opacity > 0)
        const requested = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "settingsRequested" }', test)
        requested.target = content
        keyClick(Qt.Key_Return)
        compare(requested.count, 1)
        mouseMove(configure, configure.width / 2, configure.height / 2)
        tryCompare(configure, "hovered", true)
        compare(unpin.background.color.a, 0)
    }
}
