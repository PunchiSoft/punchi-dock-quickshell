// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config"
import "../../services"

TestCase {
    name: "PunchiVirtualDesktopPolicy"

    Component {
        id: fixture
        PunchiVirtualDesktopPolicy {
            settings: PunchiShellSettings {}
            runningApplications: QtObject {
                property bool available: true
                property var virtualDesktops: []
                property var activities: []
            }
        }
    }

    function test_unavailableBackendNeverHidesTheDock() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.desktopMode = "selected"
        policy.settings.selectedDesktops = ["2"]
        policy.runningApplications.available = false
        compare(policy.allowed, true)
        policy.runningApplications.available = true
        policy.runningApplications.virtualDesktops = [{id: 1, name: "One", current: true}]
        compare(policy.allowed, false)
    }

    function test_selectedDesktopVisibility() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.desktopMode = "selected"
        policy.settings.selectedDesktops = ["2", "4"]
        policy.runningApplications.virtualDesktops = [
            {id: 1, name: "One", current: false},
            {id: 2, name: "Two", current: true}]
        compare(policy.currentDesktopId, "2")
        compare(policy.allowed, true)
        policy.runningApplications.virtualDesktops = [
            {id: 1, name: "One", current: true},
            {id: 2, name: "Two", current: false}]
        compare(policy.allowed, false)
    }

    function test_unknownCurrentDesktopKeepsTheDockVisible() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.desktopMode = "selected"
        policy.settings.selectedDesktops = ["2"]
        policy.runningApplications.virtualDesktops = []
        compare(policy.currentDesktopId, "")
        compare(policy.allowed, true)
    }

    function test_selectedActivityVisibility() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.activityMode = "selected"
        policy.settings.selectedActivities = ["work"]
        policy.runningApplications.activities = [
            {id: "work", name: "Work", current: false},
            {id: "home", name: "Home", current: true}]
        compare(policy.currentActivityId, "home")
        compare(policy.allowed, false)
        policy.runningApplications.activities = [
            {id: "work", name: "Work", current: true}]
        compare(policy.allowed, true)
    }

    function test_desktopAndActivityMustBothAllow() {
        const policy = createTemporaryObject(fixture, this)
        policy.settings.desktopMode = "selected"
        policy.settings.selectedDesktops = ["1"]
        policy.settings.activityMode = "selected"
        policy.settings.selectedActivities = ["work"]
        policy.runningApplications.virtualDesktops = [{id: 1, name: "One", current: true}]
        policy.runningApplications.activities = [{id: "home", name: "Home", current: true}]
        compare(policy.desktopAllowed, true)
        compare(policy.activityAllowed, false)
        compare(policy.allowed, false)
    }

    function test_allModeIgnoresMatches() {
        const policy = createTemporaryObject(fixture, this)
        policy.runningApplications.virtualDesktops = [{id: 3, name: "Three", current: true}]
        policy.runningApplications.activities = [{id: "home", name: "Home", current: true}]
        compare(policy.allowed, true)
    }
}
