// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../modules/dock"
import "../../services"
import "../../config"
import org.kde.kirigami as Kirigami

TestCase {
    id: test
    name: "UpdateBadge"
    when: windowShown
    visible: true
    width: 900
    height: 400
    readonly property PunchiDockMetrics metrics: PunchiDockMetrics {}

    // Mirrors PunchiApplicationCatalog: count/get, with KDE's `.desktop` storage ids.
    component RowCatalog: QtObject {
        property var rows: []
        readonly property int count: rows.length
        readonly property int revision: 0
        function get(index) { return rows[index] }
    }
    property var badgeCatalog: RowCatalog {
        rows: [
            {appId: "files", desktopId: "org.kde.dolphin.desktop"},
            {appId: "discover", desktopId: "org.kde.discover.desktop"},
            {appId: "terminal", desktopId: "org.kde.konsole.desktop"},
        ]
    }
    // A dock that pins another supported update front-end instead of Discover.
    component GnomeEntries: ListModel {
        ListElement { appId: "files"; desktopId: "org.kde.dolphin"; title: "Files"
            iconName: "system-file-manager" }
        ListElement { appId: "software"; desktopId: "org.gnome.Software"; title: "Software"
            iconName: "system-software-update" }
    }
    property var gnomeCatalog: RowCatalog {
        rows: [
            {appId: "files", desktopId: "org.kde.dolphin.desktop"},
            {appId: "software", desktopId: "org.gnome.Software.desktop"},
        ]
    }

    Component {
        id: stillFixture
        PunchiDockView {
            entries: PunchiDockFixtureModel {}
            reducedMotion: true
            updateState: PunchiUpdateNotice {
                settings: PunchiShellSettings {}
                catalog: test.badgeCatalog
                backend: QtObject {
                    property int revision: 0
                    property int count: 0
                    property int securityCount: 0
                    property int state: 2
                    property string backendName: "dnf5"
                    property bool systemAvailable: true
                    property bool flatpakAvailable: false
                    property bool firmwareAvailable: false
                    property bool updating: false
                    function refresh() {}
                }
            }
        }
    }

    Component {
        id: animatedFixture
        PunchiDockView {
            entries: PunchiDockFixtureModel {}
            reducedMotion: false
            updateState: PunchiUpdateNotice {
                settings: PunchiShellSettings {}
                catalog: test.badgeCatalog
                backend: QtObject {
                    property int revision: 0
                    property int count: 0
                    property int securityCount: 0
                    property int state: 2
                    property string backendName: "dnf5"
                    property bool systemAvailable: true
                    property bool flatpakAvailable: false
                    property bool firmwareAvailable: false
                    property bool updating: false
                    function refresh() {}
                }
            }
        }
    }

    Component {
        id: gnomeFixture
        PunchiDockView {
            entries: GnomeEntries {}
            reducedMotion: true
            updateState: PunchiUpdateNotice {
                settings: PunchiShellSettings {}
                catalog: test.gnomeCatalog
                backend: QtObject {
                    property int revision: 0
                    property int count: 0
                    property int securityCount: 0
                    property int state: 2
                    property string backendName: "dnf5"
                    property bool systemAvailable: true
                    property bool flatpakAvailable: false
                    property bool firmwareAvailable: false
                    property bool updating: false
                    function refresh() {}
                }
            }
        }
    }

    // Same dock, but no supported update front-end is pinned.
    Component {
        id: noUpdaterFixture
        PunchiDockView {
            entries: PunchiDockFixtureModel {}
            reducedMotion: true
            updateState: PunchiUpdateNotice {
                settings: PunchiShellSettings {}
                catalog: RowCatalog {
                    rows: [{appId: "discover", desktopId: "org.kde.discover.devel.desktop"}]
                }
                backend: QtObject {
                    property int revision: 0
                    property int count: 0
                    property int securityCount: 0
                    property int state: 2
                    property string backendName: "dnf5"
                    property bool systemAvailable: true
                    property bool flatpakAvailable: false
                    property bool firmwareAvailable: false
                    property bool updating: false
                    function refresh() {}
                }
            }
        }
    }

    function init(): void { failOnWarning(/.*/) }

    function badge(dock, appId) { return findChild(dock, "launcher-update-badge-" + appId) }

    function update(dock, count, securityCount) {
        dock.updateState.backend.count = count
        dock.updateState.backend.securityCount = securityCount || 0
        dock.updateState.backend.revision++
    }

    function setApplying(dock, applying) {
        dock.updateState.backend.updating = applying
        dock.updateState.backend.revision++
    }

    function test_badgeOnlyOnDiscover(): void {
        const dock = createTemporaryObject(stillFixture, test)
        verify(dock)
        const discover = findChild(dock, "launcher-discover")
        const files = findChild(dock, "launcher-files")
        const marker = badge(dock, "discover")
        verify(marker)
        verify(!marker.visible)
        compare(discover.updateCount, 0)
        update(dock, 3)
        compare(discover.updateCount, 3)
        compare(files.updateCount, 0)
        compare(marker.visible, true)
        compare(marker.opacity, 1)
        compare(marker.label, "3")
        update(dock, 120)
        compare(marker.label, "99+")
        update(dock, 0)
        compare(marker.visible, false)
    }

    // The badge follows the update front-end that is actually pinned, so the dock
    // never assumes a distribution's default updater.
    function test_badgeFollowsPinnedUpdater(): void {
        const dock = createTemporaryObject(gnomeFixture, test)
        const software = findChild(dock, "launcher-software")
        const files = findChild(dock, "launcher-files")
        verify(software)
        update(dock, 5)
        compare(dock.updateState.targetAppId, "software")
        compare(software.updateCount, 5)
        compare(files.updateCount, 0)
        verify(badge(dock, "software").visible)
        verify(!badge(dock, "files").visible)
    }

    function test_noBadgeWithoutSupportedUpdater(): void {
        const dock = createTemporaryObject(noUpdaterFixture, test)
        const discover = findChild(dock, "launcher-discover")
        update(dock, 5)
        compare(dock.updateState.targetAppId, "")
        compare(discover.updateCount, 0)
        verify(!badge(dock, "discover").visible)
    }

    // No arbitrary pixel sizes: every badge metric comes from Kirigami.
    function test_badgeUsesThemeMetrics(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        compare(marker.baseSize, Kirigami.Units.iconSizes.small)
        compare(marker.baseFontPixelSize, Kirigami.Theme.smallFont.pixelSize)
        compare(discover.metrics.badgeInset, Kirigami.Units.smallSpacing)
        // 16 px against the default 40 px launcher icon: the share a system
        // notification badge uses, and it grows with the icon from there.
        fuzzyCompare(marker.baseSize / metrics.iconSize, 0.4, 0.01)
        verify(marker.haloScale > 1)
        verify(marker.haloScale <= 1 + Kirigami.Units.smallSpacing * 2 / marker.baseSize)
    }

    function test_fillFollowsUpdateSeverity(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const marker = badge(dock, "discover")
        update(dock, 2)
        compare(marker.fillColor.toString(), Kirigami.Theme.neutralTextColor.toString())
        compare(marker.contentColor.toString(), Kirigami.Theme.textColor.toString())
        update(dock, 2, 2)
        compare(marker.fillColor.toString(), Kirigami.Theme.negativeTextColor.toString())
        update(dock, 2, 0)
        compare(marker.fillColor.toString(), Kirigami.Theme.neutralTextColor.toString())
    }

    function test_badgeTravelsWithMagnifiedIcon(): void {
        const dock = createTemporaryObject(stillFixture, test)
        update(dock, 2)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        verify(marker.visible)
        const inset = discover.metrics.badgeInset
        // The badge centre sits on the icon's lower-right corner, nudged inward so
        // it overlaps the icon like the dots KDE paints for update notifications.
        const restCenter = marker.mapToItem(dock, marker.width / 2, marker.height / 2)
        const restDiameter = marker.width * marker.scale * discover.scale
        fuzzyCompare(restCenter.x,
            discover.iconTopCenter.x + (discover.iconSize / 2 - inset) * discover.scale, 0.5)
        fuzzyCompare(restCenter.y,
            discover.iconTopCenter.y + (discover.iconSize - inset) * discover.scale, 0.5)
        // Touching, not floating: the disc reaches past the icon's corner.
        const iconRight = discover.iconTopCenter.x + discover.iconSize * discover.visualIconScale / 2
        const iconBottom = discover.iconTopCenter.y + discover.iconSize * discover.visualIconScale
        verify(restCenter.x - restDiameter / 2 < iconRight,
            "gap=" + (restCenter.x - restDiameter / 2 - iconRight))
        verify(restCenter.y - restDiameter / 2 < iconBottom,
            "gap=" + (restCenter.y - restDiameter / 2 - iconBottom))
        mouseMove(discover)
        verify(discover.visualIconScale > 1)
        const zoomedCenter = marker.mapToItem(dock, marker.width / 2, marker.height / 2)
        const zoomedDiameter = marker.width * marker.scale * discover.scale
        fuzzyCompare(zoomedCenter.x,
            discover.iconTopCenter.x + (discover.iconSize / 2 - inset) * discover.scale, 0.5)
        fuzzyCompare(zoomedCenter.y,
            discover.iconTopCenter.y + (discover.iconSize - inset) * discover.scale, 0.5)
        // Full scale: the badge grows with the icon instead of being left behind.
        fuzzyCompare(zoomedDiameter / restDiameter, discover.visualIconScale, 0.001)
        // The dock grows the icon upward from its resting edge, so the lower-right
        // corner keeps its height while still growing with the icon.
        fuzzyCompare(zoomedCenter.y, restCenter.y, 0.5)
        // Laid out at maximum magnification and counter-scaled: at rest the glyphs
        // are downscaled and at the wave peak they are drawn 1:1, never upscaled.
        fuzzyCompare(marker.width, marker.baseSize * marker.maximumScale, 0.001)
        fuzzyCompare(restDiameter * discover.maximumIconScale, marker.width, 0.001)
    }

    function test_settingHidesBadgeWithoutRestart(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        update(dock, 3)
        compare(marker.visible, true)
        dock.updateState.settings.updateBadgeEnabled = false
        compare(discover.updateCount, 0)
        compare(marker.visible, false)
        dock.updateState.settings.updateBadgeEnabled = true
        compare(discover.updateCount, 3)
        compare(marker.visible, true)
    }

    function test_accessibleDescriptionReportsCount(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        update(dock, 3)
        compare(discover.Accessible.description, "3 updates available")
        update(dock, 1)
        compare(discover.Accessible.description, "1 update available")
        update(dock, 2, 1)
        compare(discover.Accessible.description, "2 security updates available")
        update(dock, 0)
        compare(discover.Accessible.description, "")
    }

    // The disc must paint opaque pixels over the lower-right icon corner, not
    // only report a size.
    function test_badgePaintsOverTheIconCorner(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const marker = badge(dock, "discover")
        verify(waitForRendering(dock))
        const point = marker.mapToItem(dock,
            marker.width / 2 - marker.width * 0.22, marker.height / 2 - marker.height * 0.22)
        const before = grabImage(dock)
        update(dock, 5)
        verify(waitForRendering(dock))
        const after = grabImage(dock)
        verify(after.alpha(point.x, point.y) > 200,
            "alpha=" + after.alpha(point.x, point.y))
        const delta = Math.abs(after.red(point.x, point.y) - before.red(point.x, point.y))
            + Math.abs(after.green(point.x, point.y) - before.green(point.x, point.y))
            + Math.abs(after.blue(point.x, point.y) - before.blue(point.x, point.y))
        verify(delta > 30, "delta=" + delta)
        // The fill carries the KDE update-notification color, never the window
        // palette, which resolves to a washed-out highlight inside Quickshell.
        const expected = Qt.color(Kirigami.Theme.neutralTextColor)
        verify(Math.abs(after.red(point.x, point.y) - Math.round(expected.r * 255)) < 12,
            "red=" + after.red(point.x, point.y) + " expected=" + Math.round(expected.r * 255))
        verify(Math.abs(after.green(point.x, point.y) - Math.round(expected.g * 255)) < 12,
            "green=" + after.green(point.x, point.y) + " expected=" + Math.round(expected.g * 255))
        verify(Math.abs(after.blue(point.x, point.y) - Math.round(expected.b * 255)) < 12,
            "blue=" + after.blue(point.x, point.y) + " expected=" + Math.round(expected.b * 255))
    }

    function test_reducedMotionKeepsFinalState(): void {        const dock = createTemporaryObject(stillFixture, test)
        const marker = badge(dock, "discover")
        update(dock, 1, 1)
        compare(marker.visible, true)
        compare(marker.opacity, 1)
        compare(marker.fillColor.toString(), Kirigami.Theme.negativeTextColor.toString())
        wait(60)
        compare(findChild(marker, "launcher-update-badge-halo").opacity, 0)
    }

    function test_pulseOnlyForNewCountsWhileVisible(): void {
        const dock = createTemporaryObject(animatedFixture, test)
        const marker = badge(dock, "discover")
        const halo = findChild(marker, "launcher-update-badge-halo")
        verify(halo)
        // First appearance is the entry transition, not a new-update pulse.
        update(dock, 2)
        wait(60)
        compare(halo.opacity, 0)
        update(dock, 4)
        wait(60)
        verify(halo.opacity > 0)
        tryCompare(halo, "opacity", 0, 1000)
    }

    // While PackageKit applies updates the disc carries the tray's update-busy
    // glyph instead of the count that is being installed.
    function test_busyBadgeShowsTrayGlyph(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        const glyph = findChild(marker, "launcher-update-badge-glyph")
        verify(glyph)
        update(dock, 4, 1)
        verify(!glyph.visible)
        setApplying(dock, true)
        verify(discover.updateApplying)
        verify(marker.visible)
        verify(glyph.visible)
        compare(glyph.source.toString(), "update-busy")
        compare(marker.fillColor.toString(), Kirigami.Theme.neutralTextColor.toString())
        compare(discover.Accessible.description, "Installing updates")
        setApplying(dock, false)
        verify(!glyph.visible)
        compare(marker.label, "4")
        compare(discover.Accessible.description, "4 security updates available")
    }

    // A transaction that ends with nothing left hides the badge instead of
    // leaving the pre-install count on screen.
    function test_busyBadgeDisappearsAfterInstall(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        update(dock, 2)
        setApplying(dock, true)
        verify(marker.visible)
        update(dock, 0)
        setApplying(dock, false)
        compare(discover.updateCount, 0)
        compare(marker.visible, false)
    }

    // The Updates switch removes the busy state too, without a restart.
    function test_settingHidesBusyBadge(): void {
        const dock = createTemporaryObject(stillFixture, test)
        const discover = findChild(dock, "launcher-discover")
        const marker = badge(dock, "discover")
        update(dock, 3)
        setApplying(dock, true)
        verify(marker.visible)
        dock.updateState.settings.updateBadgeEnabled = false
        compare(discover.updateApplying, false)
        compare(marker.visible, false)
        dock.updateState.settings.updateBadgeEnabled = true
        compare(discover.updateApplying, true)
        verify(marker.visible)
    }

    // No animation is added for the busy state: a count change while PackageKit
    // applies updates must not fire the new-update halo.
    function test_busyStateDoesNotPulse(): void {
        const dock = createTemporaryObject(animatedFixture, test)
        const marker = badge(dock, "discover")
        const halo = findChild(marker, "launcher-update-badge-halo")
        update(dock, 2)
        wait(60)
        setApplying(dock, true)
        update(dock, 5)
        wait(60)
        compare(halo.opacity, 0)
    }
}
