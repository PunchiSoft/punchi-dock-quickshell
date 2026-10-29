// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Punchi.Kde as Native
import "../../services"
import "../../modules/dock"

TestCase {
    id: test
    name: "DockItemStartupMetadata"
    when: windowShown
    visible: true
    width: 650
    height: 400
    Component {
        id: fixture
        Item {
            width: 650; height: 400
            property alias catalog: catalog
            property alias dockPins: dockPins
            property alias settingsPins: settingsPins
            property alias view: view
            // Observe the native row before any QML title binding is supplied.
            Native.DockItemCatalog { id: catalog }
            PunchiPinnedApplications { id: dockPins; catalog: catalog; pinnedIds: ["item:trash"] }
            PunchiPinnedApplications { id: settingsPins; catalog: catalog; pinnedIds: ["item:trash"] }
            Native.DockApplicationsModel { id: items; pinned: dockPins; catalog: catalog }
            PunchiDockView { id: view; anchors.bottom: parent.bottom; entries: items; magnificationEnabled: false }
        }
    }
    function init(): void { failOnWarning(/.*/) }
    function test_initialFieldsAndLateTitleUpdatesReachBothProjections() {
        const subject=createTemporaryObject(fixture,test)
        verify(subject)
        compare(typeof subject.catalog.get(0).title,"string")
        compare(subject.dockPins.count,1)
        compare(subject.settingsPins.count,1)
        compare(subject.dockPins.get(0).title,"")
        compare(subject.settingsPins.get(0).title,"")
        tryCompare(subject.view,"itemCount",1)
        const tile=findChild(subject.view,"launcher-item:trash")
        verify(tile)
        compare(tile.title,"")
        subject.catalog.trashTitle="Owned Trash"
        subject.catalog.trashIconName="user-trash-full"
        tryCompare(tile,"title","Owned Trash")
        compare(subject.dockPins.get(0).title,"Owned Trash")
        compare(subject.settingsPins.get(0).title,"Owned Trash")
        tryCompare(tile,"iconName","user-trash-full")
        subject.catalog.trashTitle=""
        tryCompare(tile,"title","")
        compare(typeof subject.settingsPins.get(0).title,"string")
    }
}
