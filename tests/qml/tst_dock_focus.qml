// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"

TestCase {
    id: test
    name: "DockFocusOwnership"
    when: windowShown
    visible: true
    width: 900
    height: 350
    Component {
        id: fixture
        DockView {
            id: dock
            entries: DockFixtureModel {}
            reducedMotion: true
            magnificationEnabled: false
            readonly property DockFocusPolicy testPolicy: DockFocusPolicy {
                surfaceVisible: dock.visible
                menuOpen: dock.contextMenuOpen
                keyboardNavigationRequested: dock.keyboardNavigationRequested
            }
        }
    }
    SignalSpy { id: activation; signalName: "itemActivated" }
    function init() { failOnWarning(/.*/); mouseMove(test, 890, 340) }
    function createView(): var {
        const dock = createTemporaryObject(fixture, test)
        verify(dock)
        verify(waitForRendering(dock))
        activation.target = dock; activation.clear()
        return dock
    }
    function test_pointerRevealAndRepeatedClicksNeverRequestKeyboard() {
        const dock = createView()
        dock.visible = false
        compare(dock.testPolicy.acceptsKeyboard, false)
        dock.visible = true
        compare(dock.testPolicy.acceptsKeyboard, false)
        const tile = findChild(dock, "launcher-files")
        mouseMove(tile)
        compare(dock.testPolicy.acceptsKeyboard, false)
        for (let click = 0; click < 2; ++click) {
            mousePress(tile)
            compare(dock.testPolicy.acceptsKeyboard, false)
            mouseRelease(tile)
            compare(dock.testPolicy.acceptsKeyboard, false)
        }
        compare(activation.count, 2)
    }
    function test_keyboardModeRemainsUsableUntilPointerOrHide() {
        const dock = createView()
        verify(dock.focusItem(0))
        compare(dock.testPolicy.acceptsKeyboard, true)
        keyClick(Qt.Key_Right)
        compare(dock.currentIndex, 1)
        keyClick(Qt.Key_Return)
        compare(activation.signalArguments[0][0], "terminal")
        const tile = findChild(dock, "launcher-files")
        mouseClick(tile)
        compare(dock.keyboardNavigationRequested, false)
        compare(dock.testPolicy.acceptsKeyboard, false)
        verify(dock.focusItem(0))
        dock.visible = false
        compare(dock.keyboardNavigationRequested, false)
        compare(dock.testPolicy.acceptsKeyboard, false)
        dock.visible = true
        compare(dock.testPolicy.acceptsKeyboard, false)
    }
    function test_menuHasKeyboardWithoutMakingPointerRevealFocusable() {
        const dock = createView()
        dock.contextMenuOpen = true
        compare(dock.testPolicy.acceptsKeyboard, true)
        dock.contextMenuOpen = false
        compare(dock.testPolicy.acceptsKeyboard, false)
        dock.contextMenuOpen = true
        dock.visible = false
        compare(dock.testPolicy.acceptsKeyboard, false)
    }
}
