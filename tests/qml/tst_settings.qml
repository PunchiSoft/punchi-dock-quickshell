// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
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
        compare(settings.pinnedIds.length, 10)
        compare(settings.pinnedIds[8], "item:downloads")
        compare(settings.pinnedIds[9], "item:trash")
        const data = JSON.parse(JSON.stringify(settings.snapshot()))
        data.pinnedIds = ["terminal"]
        data.reducedMotion = true
        data.panelMode = "desktop"
        compare(settings.restore(data), true)
        compare(settings.effectiveReducedMotion, true)
        compare(settings.pinnedIds[0], "terminal")
        compare(settings.panelMode, "dodge-windows")
    }
    function test_folderContainers() {
        const settings = createTemporaryObject(settingsFixture, test)
        // The built-in container keeps its historical id and the empty path
        // that the native model resolves to the user's download location.
        compare(settings.container("item:downloads").id, "downloads")
        compare(settings.container("item:downloads").path, "")
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
        compare(data.version, 6)
        compare(data.containers.length, 2)
        const restored = createTemporaryObject(settingsFixture, test)
        verify(restored.restore(data))
        compare(restored.container(id).path, "/tmp/other")
        restored.containers = []
        verify(restored.restore(data))
        compare(restored.containers.length, 2)
    }
}
