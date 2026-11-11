// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/menu"
import "../../services"

// The menu must not create a delegate per application. The worst-case fixture
// grows the catalogue and asserts that the model rows grow while the created
// delegates stay bounded by the viewport.
TestCase {
    id: test
    name: "PunchiMenuScale"
    when: windowShown
    visible: true
    width: 1200
    height: 700

    property int requested: 0

    function catalogue(count): var {
        const result = []
        for (let index = 0; index < count; ++index)
            result.push({appId: "app" + index, name: "Application " + index,
                categories: ["Graphics"]})
        return result
    }

    Component {
        id: fixture
        PunchiMenuSections {
            width: 1200
            height: 600
            active: true
            motionEnabled: false
            showScrollBar: false
            menuState: PunchiMenuState {
                applications: test.catalogue(test.requested)
                columns: 7
                rows: 4
                applicationOrder: "categories"
            }
        }
    }

    function init(): void {
        failOnWarning(/.*/)
    }

    function sectionsView(view): var {
        return findChild(view, "menuSectionsView")
    }

    function createdDelegates(list): int {
        let count = 0
        for (const child of list.contentItem.children)
            if (child.objectName === "menuRowDelegate") ++count
        return count
    }

    function measure(count): var {
        test.requested = count
        const view = createTemporaryObject(fixture, test)
        verify(view !== null)
        wait(300)
        const list = sectionsView(view)
        verify(list !== null)
        const result = {
            rows: view.menuState.displayRows.length,
            created: createdDelegates(list),
            view: view
        }
        return result
    }

    function test_82Applications() {
        const result = measure(82)
        // One heading and twelve rows of seven cells.
        compare(result.rows, 13)
        verify(result.created > 0 && result.created < 20)
        result.view.destroy()
    }

    function test_500ApplicationsKeepTheSameDelegateCount() {
        const small = measure(82)
        const smallCreated = small.created
        small.view.destroy()
        wait(50)
        const large = measure(500)
        // One heading and seventy-two rows.
        compare(large.rows, 73)
        verify(large.created > 0 && large.created < 20)
        // The viewport is the same; the catalogue is not.
        verify(Math.abs(large.created - smallCreated) <= 1)
        large.view.destroy()
    }

    function test_1000ApplicationsKeepTheSameDelegateCount() {
        const result = measure(1000)
        // One heading and one hundred forty-three rows.
        compare(result.rows, 144)
        verify(result.created > 0 && result.created < 20)
        // A search collapses the listing to the matching rows only.
        result.view.menuState.searchText = "Application 500"
        wait(150)
        compare(result.view.menuState.displayRows.length, 1)
        verify(createdDelegates(sectionsView(result.view)) < 5)
        result.view.destroy()
    }
}
