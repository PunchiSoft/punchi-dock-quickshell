// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import QtTest
import "../../modules/dock"

TestCase {
    id: test
    name: "DockPlacesMenu"
    when: windowShown
    Component {
        id: fixture
        Window {
            id: viewport
            visible: true
            width: 650
            height: 900
            property alias menu: popup
            property alias places: placesModel
            property alias source: anchor
            property int openRequests: 0
            property string openedResource: ""
            Item { id: anchor; x: 320; y: 830; width: 40; height: 40 }
            ListModel {
                id: placesModel
                property int remainingCount: 3
                property string groupName: ""
                ListElement { resource: "file:///owned/home"; name: "Owned Home"; iconName: "user-home"; groupName: "Places"; isGroup: false; available: true }
                ListElement { resource: ""; name: "Remote"; iconName: ""; groupName: "Remote"; isGroup: true; available: true }
            }
            ListModel {
                id: recents
                ListElement { resource: "file:///owned/recent"; name: "Owned recent"; iconName: "folder" }
            }
            DockContextPopup {
                id: popup
                hostWindow: viewport
                places: placesModel
                usesPlaces: true
                recentDocuments: recents
                onMorePlacesRequested: {
                    placesModel.remainingCount = 0
                    placesModel.append({resource: "file:///owned/extra", name: "Owned extra", iconName: "folder",
                        groupName: "Places", isGroup: false, available: true})
                }
                onPlacesGroupRequested: function(group) {
                    placesModel.groupName = group
                    placesModel.clear()
                    placesModel.append({resource: "sftp://example.invalid/owned", name: "Owned remote", iconName: "folder-remote",
                        groupName: group, isGroup: false, available: true})
                }
                onPlacesBackRequested: {
                    placesModel.groupName = ""
                    placesModel.clear()
                    placesModel.append({resource: "file:///owned/home", name: "Owned Home", iconName: "user-home",
                        groupName: "Places", isGroup: false, available: true})
                }
                onPlaceRequested: function(resource) {
                    viewport.openRequests++
                    viewport.openedResource = resource
                    if (!popup.visible) test.fail("Place activation must precede dismissal")
                }
            }
        }
    }
    function init() { failOnWarning(/.*/) }
    function activate(item: Item): void {
        verify(item.visible && item.enabled)
        item.forceActiveFocus()
        keyClick(Qt.Key_Return)
    }
    function test_expandNavigateAndOpenWithinSameBalloon() {
        const viewport = createTemporaryObject(fixture, test)
        const menu = viewport.menu
        menu.openForItem(viewport.source, "Files")
        tryCompare(menu, "opened", true)
        const initialHeight = viewport.height
        const resize = createTemporaryQmlObject('import QtTest; SignalSpy { signalName: "heightChanged" }', test)
        resize.target = viewport
        verify(!findChild(menu.mainItem, "forgetRecentAction").visible)
        const header = findChild(menu.mainItem, "placesSectionHeader")
        compare(header.text, "Places")
        const more = findChild(menu.mainItem, "morePlacesAction")
        compare(more.text, "3 more Places…")
        activate(more)
        tryCompare(more, "visible", false)
        compare(menu.visible, true)
        compare(viewport.height, initialHeight)
        const group = findChild(menu.mainItem, "placeGroup-Remote")
        verify(group.submenu)
        activate(group)
        tryCompare(header, "text", "Remote")
        const back = findChild(menu.mainItem, "backToPlacesAction")
        tryCompare(back, "activeFocus", true)
        compare(menu.visible, true)
        activate(back)
        tryCompare(header, "text", "Places")
        compare(menu.visible, true)
        const place = findChild(menu.mainItem, "place-file:///owned/home")
        activate(place)
        tryCompare(menu, "visible", false)
        compare(viewport.openRequests, 1)
        compare(viewport.openedResource, "file:///owned/home")
        compare(resize.count, 0)
        menu.openForItem(viewport.source, "Files")
        tryCompare(menu, "opened", true)
        menu.usesPlaces = false
        tryCompare(findChild(menu.mainItem, "forgetRecentAction"), "visible", true)
        keyClick(Qt.Key_Escape)
        tryCompare(menu, "visible", false)
        tryCompare(viewport.source, "activeFocus", true)
    }
}
