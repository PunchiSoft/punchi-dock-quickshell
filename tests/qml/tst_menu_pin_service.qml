// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../services"
import "../../config"

TestCase {
    id: test
    name: "PunchiMenuPinService"

    Component {
        id: fixture
        QtObject {
            id: root
            property PunchiShellSettings settings: PunchiShellSettings {
                id: shellSettings
            }
            property PunchiApplicationPinService service: PunchiApplicationPinService {
                settings: shellSettings
                catalog: null
            }
        }
    }

    function test_pinAndUnpinAnApplicationId() {
        const root = createTemporaryObject(fixture, test)
        verify(root !== null)
        const service = root.service
        const settings = root.settings
        const appId = "desktop:org.kde.dolphin"
        compare(service.isPinned(appId), false)
        verify(service.canPinApp(appId))
        verify(service.pinApp(appId))
        compare(service.isPinned(appId), true)
        verify(settings.pinnedIds.indexOf(appId) >= 0)
        verify(!service.canPinApp(appId))
        verify(service.unpinApp(appId))
        compare(service.isPinned(appId), false)
        verify(settings.pinnedIds.indexOf(appId) < 0)
    }
}
