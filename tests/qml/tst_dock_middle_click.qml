// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../modules/dock"

TestCase {
    id: test
    name: "DockMiddleClick"
    width: 800
    height: 450
    visible: true
    when: windowShown
    function init() { failOnWarning(/.*/) }
    Component {
        id: fixture
        DockView {
            entries: ListModel {
                ListElement { appId: "files"; title: "Files"; iconName: "folder" }
                ListElement { appId: "browser"; title: "Browser"; iconName: "internet-web-browser" }
            }
            width: implicitWidth
            height: implicitHeight
            magnificationEnabled: false
            reducedMotion: true
        }
    }
    SignalSpy { id: activation; signalName: "itemActivated" }
    SignalSpy { id: newWindow; signalName: "itemNewWindowRequested" }
    function test_middleButtonUsesNewWindowIntentOnly() {
        const dock = createTemporaryObject(fixture, test)
        verify(dock)
        activation.target = dock; activation.clear()
        newWindow.target = dock; newWindow.clear()
        const tile = findChild(dock, "launcher-files")
        verify(tile)
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.MiddleButton)
        compare(newWindow.count, 1)
        compare(newWindow.signalArguments[0][0], "files")
        compare(activation.count, 0)
        mouseClick(tile, tile.width / 2, tile.height / 2, Qt.LeftButton)
        compare(activation.count, 1)
        compare(newWindow.count, 1)
        dock.focusItem(1)
        keyClick(Qt.Key_Return)
        compare(activation.count, 2)
        compare(newWindow.count, 1)
    }
    function test_removeKeyboardFocusedTaskKeepsNearestLauncher() {
        const dock = createTemporaryObject(fixture, test)
        verify(waitForRendering(dock))
        verify(dock.focusItem(0))
        const files = findChild(dock, "launcher-files")
        tryCompare(files, "activeFocus", true)
        tryCompare(files, "visualFocus", true)
        compare(dock.keyboardFocusId, "files")
        dock.entries.remove(0)
        tryCompare(dock, "itemCount", 1)
        tryVerify(() => findChild(dock, "launcher-browser").activeFocus)
        compare(dock.currentIndex, 0)
    }
}
