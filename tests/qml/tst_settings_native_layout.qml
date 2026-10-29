// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as Components
import "../../adapters/kde"
import "../../config"
import "../../modules/settings"

TestCase {
    id: test
    name: "NativeSettingsLayout"
    when: windowShown
    width: 1000
    height: 800
    visible: true
    Component {
        id: accountFixture
        QtObject {
            property string fullName: "Owned User"
            property string loginName: "owned-user"
            property url faceIconUrl: Qt.resolvedUrl("../fixtures/avatar.svg")
        }
    }
    Component { id: profileFixture; UserProfile {} }
    Component { id: headerFixture; SettingsUserHeader {} }
    Component { id: windowFixture; SettingsWindow { settings: ShellSettings {} } }
    Component {
        id: scaleFixture
        SettingsScaleControl {
            property bool mirroredLabels: false
            LayoutMirroring.enabled: mirroredLabels
            LayoutMirroring.childrenInherit: true
            title: "Magnification"
            minimumText: "No"
            nearMinimumText: "Small"
            maximumText: "Large"
            controlName: "scaleFixture"
            from: 100; to: 300; stepSize: 10
        }
    }
    function init(): void {
        failOnWarning(/^(?!This plugin does not support raise\(\)$).*/)
    }
    function profile(): var {
        const account = createTemporaryObject(accountFixture, test)
        return createTemporaryObject(profileFixture, test, {account: account})
    }
    function openWindow(): var {
        const window = createTemporaryObject(windowFixture, test)
        findChild(window.contentItem, "settingsUserHeader").profile = profile()
        window.open()
        verify(waitForRendering(window.contentItem))
        return window
    }
    function control(window: var, name: string): var {
        const item = findChild(window.contentItem, name)
        verify(item !== null, name)
        return item
    }
    function test_nativeProfileNotificationsAndLocalSource(): void {
        const data = profile()
        const header = createTemporaryObject(headerFixture, test, {profile: data})
        const name = findChild(header, "settingsUserName")
        const avatar = findChild(header, "settingsUserAvatar")
        compare(name.text, "Owned User")
        compare(avatar.source, data.account.faceIconUrl)
        compare(avatar.cache, false)
        data.account.fullName = ""
        compare(name.text, "owned-user")
        data.account.loginName = "changed-user"
        compare(name.text, "changed-user")
        const source = data.account.faceIconUrl
        // KUser's documented update sequence invalidates an unchanged filename.
        data.account.faceIconUrl = ""
        compare(avatar.source.toString(), "")
        data.account.faceIconUrl = source
        compare(avatar.source, source)
        data.account.faceIconUrl = "https://example.invalid/avatar.svg"
        compare(avatar.source.toString(), "")
        data.account = null
        compare(name.text, "")
        compare(avatar.source.toString(), "")
        header.profile = null
        compare(name.text, "")
    }
    function test_nativeAvatarMaskOrCircularSoftwareFallback(): void {
        const header = createTemporaryObject(headerFixture, test, {profile: profile()})
        const avatar = findChild(header, "settingsUserAvatar")
        verify(waitForRendering(header))
        compare(avatar.initialsMode, Components.Avatar.InitialsMode.UseIcon)
        if (!header.shadersAvailable) {
            compare(avatar.imageMode, Components.Avatar.ImageMode.AlwaysShowInitials)
            // The software path intentionally uses the circular native icon.
            return
        }
        compare(avatar.imageMode, Components.Avatar.ImageMode.AdaptiveImageOrInitals)
        tryVerify(function() {
            const image = grabImage(avatar)
            return image.red(avatar.width / 2, avatar.height / 2) > 240
                && image.green(avatar.width / 2, avatar.height / 2) < 10
        })
        const image = grabImage(avatar)
        verify(image.alpha(0, 0) < 10)
        verify(image.alpha(avatar.width / 2, avatar.height / 2) > 240)
    }
    function test_responsiveSlidersAndFixedSidebarFooter(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const layout = control(window, "settingsScaleLayout")
        const size = control(window, "iconSize")
        const zoom = control(window, "zoomScale")
        compare(layout.columns, 2)
        fuzzyCompare(size.mapToItem(view, 0, 0).y, zoom.mapToItem(view, 0, 0).y, 1)
        verify(size.mapToItem(view, size.width, 0).x < zoom.mapToItem(view, 0, 0).x)
        window.width = window.minimumWidth
        window.height = window.minimumHeight
        tryCompare(layout, "columns", 1)
        tryVerify(function() {
            return size.mapToItem(view, 0, size.height).y < zoom.mapToItem(view, 0, 0).y
        })
        const header = control(window, "settingsUserHeader")
        const apply = control(window, "applyDockSettings")
        const close = control(window, "closeDockSettings")
        const headerY = header.mapToItem(view, 0, 0).y
        const footerY = apply.mapToItem(view, 0, 0).y
        const scroll = control(window, "settingsGeneralScroll")
        verify(scroll.contentItem.contentHeight > scroll.contentItem.height)
        mouseWheel(scroll, scroll.width / 2, scroll.height / 2, 0, -480)
        tryVerify(function() { return scroll.contentItem.contentY > 0 })
        compare(header.mapToItem(view, 0, 0).y, headerY)
        compare(apply.mapToItem(view, 0, 0).y, footerY)
        verify(close.mapToItem(view, close.width, close.height).x <= view.width)
        verify(close.mapToItem(view, close.width, close.height).y <= view.height)
        const motion = control(window, "reducedMotion")
        motion.forceActiveFocus(Qt.TabFocusReason)
        tryVerify(function() {
            const point = motion.mapToItem(scroll, 0, 0)
            return point.y >= 0 && point.y + motion.height <= scroll.height
        })
        size.forceActiveFocus(Qt.TabFocusReason)
        tryVerify(function() { return size.mapToItem(scroll, 0, 0).y >= 0 })
        mouseClick(control(window, "itemsSettingsPage"))
        compare(view.currentPage, 0)
        compare(header.mapToItem(view, 0, 0).y, headerY)
        compare(apply.mapToItem(view, 0, 0).y, footerY)
        window.close()
    }
    function test_descriptiveSlidersKeepPendingAndReactiveValues(): void {
        const window = openWindow()
        const view = control(window, "dockSettingsView")
        const size = control(window, "iconSize")
        const zoom = control(window, "zoomScale")
        compare(zoom.stepSize, 10)
        size.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_End)
        compare(view.settings.sizePercent, 150)
        compare(window.settings.sizePercent, 100)
        zoom.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
        compare(view.settings.magnificationEnabled, false)
        compare(view.settings.maximumIconScale, 1)
        compare(window.settings.magnificationEnabled, true)
        verify(zoom.enabled)
        keyClick(Qt.Key_Right)
        compare(view.settings.magnificationEnabled, true)
        fuzzyCompare(view.settings.maximumIconScale, 1.1, 0.001)
        mouseClick(control(window, "applyDockSettings"))
        compare(window.settings.sizePercent, 150)
        fuzzyCompare(window.settings.maximumIconScale, 1.1, 0.001)
        verify(!window.hasPendingChanges)
        // Boundary keys must not sever the declarative external-change binding.
        window.settings.sizePercent = 125
        window.settings.maximumIconScale = 2.5
        compare(size.value, 125)
        compare(zoom.value, 250)
        window.settings.magnificationEnabled = false
        compare(zoom.value, 100)
        verify(zoom.enabled)
        zoom.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Home)
        verify(!window.hasPendingChanges)
        compare(window.settings.maximumIconScale, 2.5)
        window.close()
    }
    function test_lowRangeCaptionSpacingAndMirroring(): void {
        const scale = createTemporaryObject(scaleFixture, test, {width: 280})
        const slider = findChild(scale, "scaleFixture")
        const minimum = findChild(scale, "scaleFixtureMinimumLabel")
        const small = findChild(scale, "scaleFixtureNearMinimumLabel")
        const maximum = findChild(scale, "scaleFixtureMaximumLabel")
        let previousPosition = 0
        for (const width of [280, 420, 720]) {
            scale.width = width
            verify(waitForRendering(scale))
            compare(minimum.x, 0)
            verify(small.x >= minimum.width + Kirigami.Units.largeSpacing)
            verify(small.x + small.width <= maximum.x - Kirigami.Units.largeSpacing)
            verify(small.x + small.width / 2 < width / 4)
            verify(small.x > previousPosition)
            previousPosition = small.x
            fuzzyCompare(maximum.x + maximum.width, width, 1)
            const smallX = small.x
            scale.mirroredLabels = true
            tryCompare(slider, "mirrored", true)
            fuzzyCompare(small.x + small.width, width - smallX, 1)
            compare(maximum.x, 0)
            verify(minimum.x - small.x - small.width >= Kirigami.Units.largeSpacing)
            scale.mirroredLabels = false
            tryCompare(slider, "mirrored", false)
        }
    }
}
