// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../services"

TestCase {
    id: test
    name: "ActivateOrLaunch"
    Component {
        id: fixture
        PunchiApplicationActivationService {
            id: coordinator
            entries: ListModel {
                ListElement { appId: "files"; desktopId: "org.kde.dolphin.desktop" }
                ListElement { appId: "browser"; desktopId: "org.mozilla.firefox" }
            }
            launcher: QtObject {
                property var calls: []
                signal launchCompleted(string desktopId, bool success, string error)
                function launch(appId: string): bool { calls = calls.concat([appId]); return true }
            }
            windowState: QtObject {
                property bool configured: true
                property int revision: 0
                property var opened: []
                function isRunningDesktop(desktopId: string): bool { return opened.indexOf(desktopId) >= 0 }
                readonly property QtObject windowActivation: QtObject {
                    property bool available: true
                    property int nextId: 0
                    property var calls: []
                    signal finished(int requestId, string desktopId, string status)
                    function requestActivate(desktopId: string): int {
                        if (!available) return 0
                        calls = calls.concat([desktopId])
                        return ++nextId
                    }
                    function requestNewInstance(desktopId: string): int { return requestActivate(desktopId) }
                }
            }
        }
    }
    SignalSpy { id: rejected; signalName: "activationRejected" }
    SignalSpy { id: dispatched; signalName: "activationDispatched" }
    function init() { failOnWarning(/.*/) }
    function createService(): var {
        const service = createTemporaryObject(fixture, test)
        rejected.target = service; rejected.clear()
        dispatched.target = service; dispatched.clear()
        return service
    }
    function test_activateExistingAndLaunchOnlyAfterNoWindowResult() {
        const service = createService()
        const control = service.windowState.windowActivation
        verify(service.activate("files"))
        verify(service.activate("browser"))
        compare(service.launcher.calls.length, 0)
        // Different application replies can arrive in a different order.
        control.finished(2, "org.mozilla.firefox", "activated")
        compare(dispatched.count, 1)
        compare(dispatched.signalArguments[0][0], "browser")
        compare(service.launcher.calls.length, 0)
        control.finished(1, "org.kde.dolphin", "not-found")
        compare(service.launcher.calls, ["files"])
        control.finished(1, "org.kde.dolphin", "not-found")
        compare(service.launcher.calls.length, 1)
        verify(service.activate("browser"))
        verify(service.activate("browser"))
        compare(control.calls.length, 3) // Coalesce a still-pending normal click.
        control.finished(3, "org.mozilla.firefox", "activated")
        verify(service.activate("browser"))
        control.finished(4, "org.mozilla.firefox", "activated")
        compare(dispatched.count, 3)
        compare(service.launcher.calls.length, 1)
    }
    function test_failuresUnavailableAndUnknownIdsNeverLaunch() {
        const service = createService()
        const control = service.windowState.windowActivation
        verify(!service.activate("not-pinned"))
        compare(control.calls.length, 0)
        control.available = false
        verify(!service.activate("files"))
        control.available = true
        for (const status of ["unavailable", "rejected"]) {
            verify(service.activate("browser"))
            control.finished(control.nextId, "org.mozilla.firefox", status)
        }
        verify(service.activate("files"))
        control.finished(control.nextId, "wrong-app", "not-found")
        compare(rejected.count, 5)
        compare(service.launcher.calls.length, 0)
    }
    function test_minimizedResultCompletesWithoutLaunch() {
        const service = createService()
        verify(service.activate("browser"))
        service.windowState.windowActivation.finished(1, "org.mozilla.firefox", "minimized")
        compare(dispatched.count, 1)
        compare(rejected.count, 0)
        compare(service.launcher.calls.length, 0)
        service.windowState.windowActivation.finished(1, "org.mozilla.firefox", "minimized")
        compare(dispatched.count, 1)
    }
    function test_pendingLaunchCannotOpenRemovedOrChangedLauncher() {
        const service = createService()
        const control = service.windowState.windowActivation
        verify(service.activate("files"))
        service.entries.setProperty(0, "desktopId", "other-app")
        control.finished(1, "org.kde.dolphin", "not-found")
        verify(service.activate("browser"))
        service.entries.clear()
        control.finished(2, "org.mozilla.firefox", "not-found")
        compare(service.launcher.calls.length, 0)
        compare(rejected.count, 2)
    }
    function test_unconfiguredDevelopmentHostsKeepLaunchEntryPoint() {
        const service = createService()
        service.windowState.configured = false
        verify(service.activate("files"))
        compare(service.launcher.calls, ["files"])
        compare(service.windowState.windowActivation.calls.length, 0)
    }
    function test_startupReservationsFailureObservationAndExplicitNewWindow() {
        const service = createService()
        const control = service.windowState.windowActivation
        verify(service.activate("files"))
        verify(service.activate("files"))
        compare(control.calls.length, 1)
        control.finished(1, "org.kde.dolphin", "not-found")
        compare(service.launcher.calls, ["files"])
        verify(service.activate("files"))
        compare(control.calls.length, 1)
        service.launcher.launchCompleted("org.kde.dolphin.desktop", false, "Owned failure")
        verify(service.activate("files"))
        compare(control.calls.length, 2)
        control.finished(2, "org.kde.dolphin", "not-found")
        service.windowState.opened = ["org.kde.dolphin"]
        service.windowState.revision++
        verify(service.activate("files"))
        control.finished(3, "org.kde.dolphin", "activated")
        verify(service.activate("browser"))
        control.finished(4, "org.mozilla.firefox", "starting")
        compare(service.launcher.calls.length, 2)
        verify(service.newWindow("files"))
        control.finished(5, "org.kde.dolphin", "new-instance")
        compare(service.launcher.calls.length, 2)
        verify(service.newWindow("browser"))
        control.finished(6, "org.mozilla.firefox", "not-found")
        compare(service.launcher.calls, ["files", "files", "browser"])
        // Explicit New Window bypasses normal startup suppression.
        verify(service.newWindow("browser"))
        control.finished(7, "org.mozilla.firefox", "not-found")
        compare(service.launcher.calls.length, 4)
    }
    function test_startupReservationExpiresAfterMissingWindow() {
        const service = createService()
        service.startup.timeout = 40
        verify(service.activate("files"))
        service.windowState.windowActivation.finished(1, "org.kde.dolphin", "not-found")
        verify(service.startup.holds("org.kde.dolphin"))
        tryVerify(() => !service.startup.holds("org.kde.dolphin"), 1000)
        verify(service.activate("files"))
        compare(service.windowState.windowActivation.calls.length, 2)
    }
    function test_startupDesktopIdsDoNotUseObjectPrototypeKeys() {
        const service = createService()
        verify(service.startup.reserve("__proto__.desktop"))
        verify(service.startup.holds("__proto__"))
        verify(!service.startup.reserve("__proto__"))
        verify(service.startup.reserve("constructor.desktop"))
        compare(Object.keys(service.startup.deadlines).length, 2)
        service.startup.release("__proto__")
        verify(!service.startup.holds("__proto__"))
        verify(service.startup.holds("constructor"))
    }
}
