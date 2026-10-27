// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"
import "../../config"
import "../../modules/settings"

TestCase {
    id: test
    name: "TrashItem"
    when: windowShown
    visible: true
    width: 650
    height: 500
    Component {
        id: serviceFixture
        TrashService {
            state: QtObject {
                property bool available: true
                property bool hasItems: true
                property bool busy: false
                property int emptied: 0
                function emptyAfterConfirmation(): bool { emptied++; busy = true; return true }
            }
            launcher: QtObject {
                property int opened: 0
                function openTrash(): bool { opened++; return true }
            }
        }
    }
    Component { id: motionFixture; TrashConfirmationMotion { duration: 80 } }
    Component { id: settingsFixture; ShellSettings {} }
    Component { id: menuFixture; DockContextContent { trashItem: true } }
    Component {
        id: contentFixture
        TrashConfirmationContent { questionText: "Owned question"; warningText: "Owned warning"; canConfirm: true }
    }
    Component {
        id: orderFixture
        Item {
            width: 850; height: 800
            property alias settings: settings
            property alias view: view
            ShellSettings { id: settings; pinnedIds: ["files", "browser", "item:trash"] }
            SettingsEditService { id: edit; settings: settings }
            ListModel {
                id: catalog
                ListElement { appId: "files"; desktopId: "org.kde.dolphin"; title: "Files"; iconName: "system-file-manager" }
                ListElement { appId: "browser"; desktopId: "org.mozilla.firefox"; title: "Browser"; iconName: "internet-web-browser" }
                ListElement { appId: "item:trash"; desktopId: ""; title: "Trash"; iconName: "user-trash" }
                function application(id: string): var { return null }
                property int revision: 0
            }
            SettingsView {
                id: view
                anchors.fill: parent
                settings: edit.draft
                currentPage: 0
                applicationCatalog: catalog
                hasPendingChanges: edit.dirty
                onApplyRequested: edit.apply()
                onCloseRequested: edit.cancel()
            }
            Component.onCompleted: edit.begin()
        }
    }
    function init() { failOnWarning(/.*/) }
    function test_confirmationIsExplicitSingleAndChecksCurrentState() {
        const service = createTemporaryObject(serviceFixture,test)
        verify(!service.confirm()); compare(service.state.emptied,0)
        verify(service.open()); compare(service.launcher.opened,1)
        verify(service.requestEmpty()); verify(!service.requestEmpty())
        service.cancel(); verify(!service.confirm()); compare(service.state.emptied,0)
        verify(service.requestEmpty()); service.state.hasItems = false
        verify(!service.confirm()); compare(service.state.emptied,0)
        service.state.hasItems = true; verify(service.requestEmpty()); verify(service.confirm())
        compare(service.state.emptied,1); verify(!service.confirm()); verify(!service.requestEmpty())
        service.state.busy = false; service.state.available = false; verify(!service.requestEmpty())
    }
    function test_menuHasOnlyTrashActionsAndKeyboardCancelIsSafe() {
        const menu = createTemporaryObject(menuFixture,test)
        verify(waitForRendering(menu))
        const open = findChild(menu,"openTrashAction")
        const empty = findChild(menu,"emptyTrashAction")
        verify(open.visible); verify(empty.visible); verify(!empty.enabled)
        verify(!findChild(menu,"configureDockAction").visible)
        verify(!findChild(menu,"unpinDockAction").visible)
        menu.focusFirst(); tryCompare(open,"activeFocus",true)
        menu.canEmptyTrash = true; verify(empty.enabled)
        const content = createTemporaryObject(contentFixture,test)
        const canceled=createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "cancelRequested" }',test)
        canceled.target=content
        content.focusFirst()
        keyClick(Qt.Key_Escape);compare(canceled.count,1)
        const cancel=findChild(content,"cancelEmptyTrash")
        const confirm=findChild(content,"confirmEmptyTrash")
        content.focusFirst();keyClick(Qt.Key_Tab);tryCompare(confirm,"activeFocus",true)
        keyClick(Qt.Key_Tab);tryCompare(cancel,"activeFocus",true)
    }
    function test_motionFinishesExitAndSupportsReversalAndReducedMotion() {
        const motion = createTemporaryObject(motionFixture,test)
        motion.requested = true; compare(motion.present,true)
        tryCompare(motion,"moving",false);fuzzyCompare(motion.surfaceScale,1,0.001)
        motion.requested = false;compare(motion.present,true)
        wait(20);motion.requested = true
        compare(motion.present,true);tryCompare(motion,"moving",false)
        fuzzyCompare(motion.surfaceOpacity,1,0.001)
        motion.requested = false;tryCompare(motion,"present",false)
        motion.reducedMotion = true;motion.requested = true
        compare(motion.present,true);compare(motion.surfaceScale,1);compare(motion.moving,false)
        motion.requested = false;compare(motion.present,false);compare(motion.surfaceOpacity,0)
    }
    function test_settingsMigrateOnceAndRetainItemOrder() {
        const settings=createTemporaryObject(settingsFixture,test)
        compare(settings.pinnedIds[settings.pinnedIds.length-1],"item:trash")
        verify(settings.restore({version:1,pinnedIds:["files","browser"]}))
        compare(settings.pinnedIds,["files","browser","item:downloads","item:trash"])
        compare(settings.snapshot().version,11)
        compare(settings.snapshot().containers.length,2)
        compare(settings.snapshot().containers[0].id,"downloads")
        compare(settings.snapshot().containers[1].id,"home")
        verify(settings.restore({version:2,pinnedIds:["item:trash","files","browser"]}))
        compare(settings.pinnedIds,["item:downloads","item:trash","files","browser"])
        verify(settings.restore({version:3,pinnedIds:["item:trash","files","browser"]}))
        compare(settings.pinnedIds,["item:trash","files","browser"])
        verify(settings.restore({version:2,pinnedIds:["files"]}))
        compare(settings.pinnedIds,["files"])
        settings.reset();compare(settings.pinnedIds[10],"item:trash")
    }
    function test_itemOrderControlsApplyTrashAndDiscardPendingMove() {
        const fixture=createTemporaryObject(orderFixture,test)
        verify(waitForRendering(fixture))
        const view=fixture.view
        const trashRow=findChild(view,"configuredItem-item:trash")
        mouseClick(trashRow)
        const up=findChild(view,"moveDockItemUp")
        verify(up.enabled);mouseClick(up)
        compare(view.settings.pinnedIds,["files","item:trash","browser"])
        compare(fixture.settings.pinnedIds,["files","browser","item:trash"])
        mouseClick(findChild(view,"applyDockSettings"))
        compare(fixture.settings.pinnedIds,["files","item:trash","browser"])
        mouseClick(up)
        compare(view.settings.pinnedIds,["item:trash","files","browser"])
        mouseClick(findChild(view,"closeDockSettings"))
        compare(fixture.settings.pinnedIds,["files","item:trash","browser"])
    }
    function test_confirmationButtonsOwnThePointingHandCursor() {
        const content = createTemporaryObject(contentFixture,test)
        verify(waitForRendering(content))
        const cancel = findChild(content,"cancelEmptyTrash")
        const confirm = findChild(content,"confirmEmptyTrash")
        const cancelCursor = findChild(cancel,"trashCancelCursor")
        const confirmCursor = findChild(confirm,"trashConfirmCursor")
        verify(cancelCursor !== null && confirmCursor !== null)
        compare(cancelCursor.cursorShape, Qt.PointingHandCursor)
        compare(confirmCursor.cursorShape, Qt.PointingHandCursor)
        mouseMove(cancel, cancel.width / 2, cancel.height / 2)
        tryCompare(cancelCursor, "hovered", true)
        // A confirmation that cannot empty anything stops asking for the hand
        // instead of promising the action.
        content.canConfirm = false
        tryCompare(confirm, "enabled", false)
        tryCompare(confirmCursor, "enabled", false)
        tryCompare(confirmCursor, "hovered", false)
    }
}
