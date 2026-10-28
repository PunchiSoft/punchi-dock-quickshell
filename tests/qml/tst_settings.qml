// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"
import "../../modules/settings"
TestCase {
    id: test
    name: "DockSettings"
    when: windowShown
    width: 600
    height: 900
    Component { id: fixture; SettingsView { settings: ShellSettings {} } }
    Component { id: settingsFixture; ShellSettings {} }
    Component {
        id: placementFixture
        SettingsView {
            settings: ShellSettings {}
            screens: [{name: "DP-1", model: "Test panel"}]
            primaryScreenName: "DP-1"
            runningApplications: QtObject {
                property bool available: true
                property var virtualDesktops: [{id: 1, name: "One", current: true},
                    {id: 2, name: "Two", current: false}]
                property var activities: [{id: "work", name: "Work", current: true}]
            }
        }
    }
    Component { id: modelFixture; PinnedApplications { catalog: DockFixtureModel {}
        pinnedIds: [] } }
    function test_reactive_controls_and_reset() {
        const view = createTemporaryObject(fixture, test)
        const settings = view.settings
        settings.panelMode = "desktop"
        compare(findChild(view, "visibilityMode").currentIndex, 2)
        const zoom = findChild(view, "zoomScale")
        zoom.forceActiveFocus()
        keyClick(Qt.Key_Home)
        compare(settings.magnificationEnabled, false)
        compare(zoom.value, 100)
        verify(zoom.enabled)
        settings.sizePercent = 150
        compare(settings.iconSize, Math.round(settings.metrics.iconSize * 1.5))
        settings.bounceEnabled = false
        compare(settings.clickDuration, 0)
        settings.reset()
        compare(settings.sizePercent, 100)
        compare(settings.magnificationEnabled, true)
        compare(settings.panelMode, "overlay")
    }
    function test_persistent_pins_reorder_and_filter() {
        const view = createTemporaryObject(fixture, test)
        const model = createTemporaryObject(modelFixture, test)
        model.pinnedIds = Qt.binding(() => view.settings.pinnedIds)
        compare(model.count, 8)
        view.settings.pinnedIds = ["files", "browser", "kate", "systemsettings", "discover", "gwenview", "okular"]
        compare(model.count, 7)
        compare(model.get(1).appId, "browser")
        view.settings.pinnedIds = view.settings.pinnedIds.concat(["terminal"])
        compare(model.get(7).appId, "terminal")
        view.settings.pinnedIds = ["files", "browser", "kate", "systemsettings", "discover", "gwenview", "terminal", "okular"]
        compare(model.get(6).appId, "terminal")
        view.settings.pinnedIds = ["okular", "files"]
        compare(model.count, 2)
        compare(model.get(0).desktopId, "org.kde.okular")
        view.settings.pinnedIds = []
        compare(model.count, 0)
    }
    function test_invalid_persistence_and_roundtrip() {
        const view = createTemporaryObject(fixture, test)
        const settings = view.settings
        compare(settings.restore({version: 999}), false)
        settings.restore({version: 1, panelMode: "dodge", sizePercent: -1,
            maximumIconScale: 99, bounceEnabled: "false", pinnedIds: ["files", "files"]})
        compare(settings.panelMode, "overlay")
        compare(settings.sizePercent, 100)
        compare(settings.maximumIconScale, 2)
        compare(settings.bounceEnabled, true)
        compare(settings.pinnedIds.length, 11)
        compare(settings.pinnedIds[2], "item:folder:home")
        compare(settings.pinnedIds[9], "item:downloads")
        compare(settings.pinnedIds[10], "item:trash")
        compare(settings.recentApplicationsEnabled, true)
        compare(settings.recentApplicationsCount, 5)
        compare(settings.updateBadgeEnabled, true)
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        data.pinnedIds = ["terminal"]
        data.reducedMotion = true
        data.panelMode = "desktop"
        data.recentApplicationsEnabled = false
        data.recentApplicationsCount = 8
        data.updateBadgeEnabled = false
        compare(settings.restore(data), true)
        compare(settings.effectiveReducedMotion, true)
        compare(settings.pinnedIds[0], "terminal")
        compare(settings.panelMode, "dodge-windows")
        compare(settings.recentApplicationsEnabled, false)
        compare(settings.recentApplicationsCount, 8)
        compare(settings.updateBadgeEnabled, false)
    }
    function test_popupAppearancePersistence() {
        const settings = createTemporaryObject(settingsFixture, test)
        compare(settings.popupScale, 1)
        // Zero means the theme's icon, so an untouched profile follows Plasma.
        compare(settings.popupIconSize, 0)
        compare(settings.popupListIconSize, 0)
        compare(settings.popupFanIconSize, 0)
        compare(settings.popupHeightPercent, 80)
        settings.popupScale = 1.15
        settings.popupIconSize = 64
        settings.popupListIconSize = 40
        settings.popupFanIconSize = 34
        settings.popupHeightPercent = 50
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        compare(data.version, 12)
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(data))
        compare(restored.popupScale, 1.15)
        compare(restored.popupIconSize, 64)
        compare(restored.popupListIconSize, 40)
        compare(restored.popupFanIconSize, 34)
        compare(restored.popupHeightPercent, 50)
        // Out-of-range values keep the profile intact instead of clamping it to
        // a size the popup cannot honour.
        verify(restored.restore({version: 11, popupScale: 4, popupIconSize: 4,
            popupListIconSize: 200, popupFanIconSize: 8, popupHeightPercent: 200}))
        compare(restored.popupScale, 1.15)
        compare(restored.popupIconSize, 64)
        compare(restored.popupListIconSize, 40)
        compare(restored.popupFanIconSize, 34)
        compare(restored.popupHeightPercent, 50)
        restored.reset()
        compare(restored.popupScale, 1)
        compare(restored.popupIconSize, 0)
        compare(restored.popupListIconSize, 0)
        compare(restored.popupFanIconSize, 0)
        compare(restored.popupHeightPercent, 80)
    }
    function test_folderContainers() {
        const settings = createTemporaryObject(settingsFixture, test)
        // The built-in containers keep the empty path the native model
        // resolves to their standard location.
        compare(settings.container("item:downloads").id, "downloads")
        compare(settings.container("item:downloads").path, "")
        compare(settings.container("item:folder:home").id, "home")
        compare(settings.container("item:folder:home").path, "")
        compare(settings.container("item:folder:home").icon, "user-home")
        compare(settings.container("item:folder:home").layout, "fan")
        compare(settings.container("item:folder:home").sortMode, "name")
        // The first-run Home container lists the standard user folders as
        // places to go, so it does not enter them; Downloads keeps browsing.
        compare(settings.container("item:folder:home").browseSubfolders, false)
        compare(settings.containerBrowseSubfolders("item:folder:home"), false)
        compare(settings.containerBrowseSubfolders("item:downloads"), true)
        compare(settings.removeContainer("item:folder:home"), false)
        compare(settings.container("files"), null)
        // A chosen folder is stored, addressable and validated.
        const id = settings.addContainer("/tmp/owned", "owned", "folder")
        compare(id, "item:folder:folder-1")
        compare(settings.container(id).path, "/tmp/owned")
        compare(settings.addContainer("relative/path", "x", ""), "")
        verify(settings.setContainerPath(id, "/tmp/other"))
        compare(settings.container(id).path, "/tmp/other")
        compare(settings.setContainerPath(id, "relative"), false)
        compare(settings.container(id).path, "/tmp/other")
        compare(settings.setContainerPath("files", "/tmp/other"), false)
        // The persisted profile carries the containers and still round-trips.
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        compare(data.version, 12)
        compare(data.containers.length, 3)
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(data))
        compare(restored.container(id).path, "/tmp/other")
        restored.containers = []
        verify(restored.restore(data))
        compare(restored.containers.length, 3)
    }
    function test_savedProfileKeepsItsContainersWithoutHome() {
        const settings = createTemporaryObject(settingsFixture, test)
        const data = {
            version: 11,
            downloadsView: "grid",
            containers: [{id: "downloads", path: "", title: "Downloads",
                icon: "folder-downloads", layout: "grid", sortMode: "modified"}],
            pinnedIds: ["files", "item:downloads", "item:trash"]
        }
        verify(settings.restore(data))
        compare(settings.container("item:folder:home"), null)
        compare(settings.containers.length, 1)
        compare(settings.pinnedIds.join(","), "files,item:downloads,item:trash")
    }
    function test_containerHiddenEntries() {
        const settings = createTemporaryObject(settingsFixture, test)
        const id = settings.addContainer("/tmp/owned", "owned", "folder")
        compare(settings.containerHiddenEntries(id), [])
        // The list holds entry names only, so a stored value cannot name a path.
        verify(settings.setContainerHiddenEntries(id, ["skip.txt", "photo.jpg"]))
        compare(settings.containerHiddenEntries(id), ["skip.txt", "photo.jpg"])
        compare(settings.setContainerHiddenEntries(id, ["skip.txt", "photo.jpg"]), false)
        compare(settings.setContainerHiddenEntries(id, ["../escape"]), false)
        compare(settings.setContainerHiddenEntries(id, ["nested/file"]), false)
        compare(settings.containerHiddenEntries(id), ["skip.txt", "photo.jpg"])
        // Every other container edit keeps the selection.
        verify(settings.setContainerPath(id, "/tmp/other"))
        verify(settings.setContainerLayout(id, "list"))
        verify(settings.setContainerSortMode(id, "name"))
        compare(settings.containerHiddenEntries(id), ["skip.txt", "photo.jpg"])
        // An empty list means "show everything".
        verify(settings.setContainerHiddenEntries(id, []))
        compare(settings.containerHiddenEntries(id), [])
        // The profile round-trips the field and a schema-8 profile keeps none.
        verify(settings.setContainerHiddenEntries(id, ["skip.txt"]))
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        compare(data.version, 12)
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(data))
        compare(restored.containerHiddenEntries(id), ["skip.txt"])
        data.version = 8
        const legacy = createTemporaryObject(settingsFixture, test)
        verify(legacy.restore(data))
        compare(legacy.containerHiddenEntries(id), [])
    }
    function test_screenAndDesktopPreferences() {
        const settings = createTemporaryObject(settingsFixture, test)
        compare(settings.screenMode, "all")
        compare(settings.avoidInnerEdgeAutoHide, true)
        settings.screenMode = "selected"
        settings.selectedScreens = ["DP-1", "HDMI-A-1"]
        settings.desktopMode = "selected"
        settings.selectedDesktops = ["1", "2"]
        settings.activityMode = "selected"
        settings.selectedActivities = ["activity-a"]
        settings.runningMarkersFollowDesktop = true
        settings.avoidInnerEdgeAutoHide = false
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        compare(data.version, 12)
        compare(data.selectedScreens.length, 2)
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(data))
        compare(restored.screenMode, "selected")
        compare(restored.selectedScreens.join(","), "DP-1,HDMI-A-1")
        compare(restored.selectedDesktops.join(","), "1,2")
        compare(restored.selectedActivities.join(","), "activity-a")
        compare(restored.runningMarkersFollowDesktop, true)
        compare(restored.avoidInnerEdgeAutoHide, false)
        // Invalid values are ignored, never applied partially.
        verify(restored.restore({version: 12, screenMode: "primary", selectedScreens: "DP-1",
            desktopMode: "current", selectedDesktops: [{}], selectedActivities: new Array(17).fill("a"),
            runningMarkersFollowDesktop: "yes"}))
        compare(restored.screenMode, "selected")
        compare(restored.selectedScreens.join(","), "DP-1,HDMI-A-1")
        compare(restored.desktopMode, "selected")
        compare(restored.runningMarkersFollowDesktop, true)
        settings.screenMode = "primary"
        compare(settings.screenMode, "all")
        settings.desktopMode = "current"
        compare(settings.desktopMode, "all")
        settings.activityMode = "current"
        compare(settings.activityMode, "all")
        // A schema-11 profile keeps the new defaults.
        const legacy = createTemporaryObject(settingsFixture, test)
        verify(legacy.restore({version: 11}))
        compare(legacy.screenMode, "all")
        compare(legacy.desktopMode, "all")
        compare(legacy.activityMode, "all")
        compare(legacy.avoidInnerEdgeAutoHide, true)
    }
    function test_placementControls() {
        const view = createTemporaryObject(placementFixture, test)
        const settings = view.settings
        view.screens = [{name: "DP-1", model: "Test panel"},
            {name: "HDMI-A-1", model: "External panel"}]
        settings.screenMode = "selected"
        const screen = findChild(view, "screen-DP-1")
        verify(screen !== null)
        screen.checked = true
        screen.clicked()
        compare(settings.selectedScreens.join(","), "DP-1")
        screen.checked = false
        screen.clicked()
        compare(settings.selectedScreens.length, 0)
        settings.desktopMode = "selected"
        const desktop = findChild(view, "desktop-2")
        verify(desktop !== null)
        desktop.checked = true
        compare(settings.selectedDesktops.join(","), "2")
        settings.activityMode = "selected"
        const activity = findChild(view, "activity-work")
        verify(activity !== null)
        activity.checked = true
        compare(settings.selectedActivities.join(","), "work")
        const markers = findChild(view, "runningMarkersFollowDesktop")
        verify(markers !== null)
        markers.checked = true
        compare(settings.runningMarkersFollowDesktop, true)
    }
    function test_disconnectedSelectionShowsFallback() {
        const view = createTemporaryObject(placementFixture, test)
        const settings = view.settings
        settings.screenMode = "selected"
        settings.selectedScreens = ["HDMI-A-1"]
        // The saved screen is unplugged and stays visible as unavailable.
        const missing = findChild(view, "screenMissing-HDMI-A-1")
        verify(missing !== null)
        verify(missing.checked)
        verify(!missing.enabled)
        // The connected screen carries the temporary fallback marker.
        const fallback = findChild(view, "screen-DP-1")
        verify(fallback !== null)
        verify(fallback.text.indexOf("Fallback") >= 0)
        verify(!fallback.checked)
        // Checking it turns the fallback into the saved selection.
        fallback.checked = true
        fallback.clicked()
        compare(settings.selectedScreens.join(","), "DP-1")
        // A configured screen that reconnects clears the fallback marker.
        settings.selectedScreens = ["HDMI-A-1"]
        view.screens = [{name: "DP-1", model: "Test panel"},
            {name: "HDMI-A-1", model: "External panel"}]
        const reconnected = findChild(view, "screen-HDMI-A-1")
        verify(reconnected !== null)
        verify(reconnected.checked)
        verify(reconnected.text.indexOf("Fallback") < 0)
        settings.selectedScreens = ["DP-1"]
        compare(fallback.text.indexOf("Fallback"), -1)
    }
    function test_placementCardScrollsAboveTheFooter() {
        const view = createTemporaryObject(placementFixture, test,
            {height: Kirigami.Units.gridUnit * 30})
        const page = findChild(view, "settingsDockGeneral")
        const viewport = findChild(view, "settingsGeneralViewport")
        const last = findChild(view, "avoidInnerEdgeAutoHide")
        verify(page !== null && viewport !== null && last !== null)
        compare(viewport.contentHeight, page.implicitHeight)
        compare(viewport.bottomMargin, 0)
        viewport.contentY = Math.max(0, viewport.contentHeight - viewport.height)
        const bottom = last.mapToItem(viewport, 0, last.height).y
        verify(bottom <= viewport.height + 1)
    }
}
