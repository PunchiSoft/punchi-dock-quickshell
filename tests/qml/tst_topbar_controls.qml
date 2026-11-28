// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../config"
import "../../services"
import "../../modules/topbar"

TestCase {
    id: test
    name: "TopBarControls"
    when: windowShown
    width: 1280
    height: 800
    QtObject {
        id: mediaPlayerA
        property bool isPlaying: true
        property bool canControl: true
        property bool canGoNext: true
        property bool canGoPrevious: false
        property bool canPlay: true
        property bool canPause: true
        property string identity: "Player A"
        property string trackTitle: "Track A"
        property string trackArtist: "Artist A"
        property int nextCalls: 0
        property int previousCalls: 0
        property int toggleCalls: 0
        function next() { nextCalls++ }
        function previous() { previousCalls++ }
        function togglePlaying() { toggleCalls++ }
    }
    QtObject {
        id: mediaPlayerB
        property bool isPlaying: false
        property bool canControl: true
        property bool canGoNext: false
        property bool canGoPrevious: true
        property bool canPlay: true
        property bool canPause: true
        property string identity: "Player B"
        property string trackTitle: "Track B"
        property string trackArtist: "Artist B"
        property int nextCalls: 0
        property int previousCalls: 0
        property int toggleCalls: 0
        function next() { nextCalls++ }
        function previous() { previousCalls++ }
        function togglePlaying() { toggleCalls++ }
    }
    QtObject {
        id: notificationProvider
        property bool available: true
        property bool reading: false
        property bool valid: true
        property string lastError: ""
        property bool inhibited: false
    }
    QtObject {
        id: mediaProvider
        property var players: []
    }
    QtObject {
        id: brightnessProvider
        property bool available: true
        property bool pending: false
        property var displays: [{
            id: "display0", label: "Built-in display", internal: true,
            brightness: 4000, maximum: 10000, percent: 40
        }]
        property var calls: []
        property int lastPercent: -1
        function setPercent(displayId, percent) {
            calls.push(displayId + ":" + percent)
            lastPercent = percent
            return true
        }
    }
    QtObject {
        id: audioProvider
        property bool available: true
        property bool ready: true
        property string nodeId: "sink-1"
        property string description: "Test output"
        property real volume: 0.4
        property bool muted: false
        property real lastVolume: -1
        property bool lastMuted: false
        function setVolume(value) { lastVolume = value; volume = value; return true }
        function setMuted(value) { lastMuted = value; muted = value; return true }
    }
    QtObject {
        id: networkProvider
        property bool available: true
        property bool wirelessEnabled: false
        property bool wirelessHardwareEnabled: true
        property bool connected: false
        property string connectionName: ""
        property bool lastRequest: false
        function setWirelessEnabled(enabled) { lastRequest = enabled; return true }
        signal changed()
    }
    QtObject {
        id: bluetoothProvider
        property bool available: true
        property int adapterCount: 2
        property string adapterName: "hci0"
        property bool powered: false
        property bool blocked: false
        property bool lastRequest: false
        function setPowered(powered) { lastRequest = powered; return true }
        signal changed()
    }
    QtObject {
        id: storageFake
        property bool available: true
        property var devices: [{
            id: "/org/freedesktop/UDisks2/drives/Test",
            name: "Test stick",
            volumes: [
                {path: "/org/freedesktop/UDisks2/block_devices/sdb1", label: "Photos", mounted: true, size: 1000},
                {path: "/org/freedesktop/UDisks2/block_devices/sdb2", label: "Backup", mounted: false, size: 1000}
            ],
            mountedCount: 1,
            protectedMounted: false,
            canRemove: true,
            ejectable: true
        }]
        property bool pending: false
        property string pendingTarget: ""
        property string lastOperation: ""
        property string lastTarget: ""
        property bool lastSuccess: false
        property string lastError: ""
        property var calls: []
        function unmountVolume(path) {
            calls.push("unmount:" + path)
            lastOperation = "unmount"
            lastTarget = path
            lastSuccess = true
            return true
        }
        function removeDrive(path) {
            calls.push("remove:" + path)
            lastOperation = "remove"
            lastTarget = path
            lastSuccess = true
            return true
        }
        function refresh() {}
    }
    QtObject {
        id: fakeControls
        property var dnd: PunchiDoNotDisturbService { provider: notificationProvider }
        property var media: PunchiMediaControlService { provider: mediaProvider }
        property var brightness: PunchiBrightnessControlService { provider: brightnessProvider }
        property var audio: PunchiAudioControlService { provider: audioProvider }
        property var network: PunchiNetworkControlService { provider: networkProvider }
        property var bluetooth: PunchiBluetoothControlService { provider: bluetoothProvider }
        property var storage: storageFake
    }
    Component { id: spyComponent; SignalSpy {} }
    Component {
        id: fixture
        PunchiTopBarView {
            width: 1280
            height: 800
            now: new Date(2026, 10, 27, 18, 7)
            controls: fakeControls
        }
    }
    function openControls(view): void {
        view.openQuickControls()
        tryCompare(findChild(view, "topBarQuickControlsPopup"), "visible", true)
        verify(waitForRendering(view))
    }
    function resetFakes(): void {
        notificationProvider.available = true
        notificationProvider.reading = false
        notificationProvider.valid = true
        notificationProvider.lastError = ""
        notificationProvider.inhibited = false
        mediaProvider.players = []
        mediaPlayerA.isPlaying = true
        mediaPlayerA.nextCalls = 0
        mediaPlayerA.previousCalls = 0
        mediaPlayerA.toggleCalls = 0
        mediaPlayerB.isPlaying = false
        mediaPlayerB.nextCalls = 0
        mediaPlayerB.previousCalls = 0
        mediaPlayerB.toggleCalls = 0
        brightnessProvider.available = true
        brightnessProvider.displays = [{
            id: "display0", label: "Built-in display", internal: true,
            brightness: 4000, maximum: 10000, percent: 40
        }]
        brightnessProvider.calls = []
        brightnessProvider.lastPercent = -1
        audioProvider.volume = 0.4
        audioProvider.muted = false
        audioProvider.nodeId = "sink-1"
        audioProvider.lastVolume = -1
        networkProvider.wirelessEnabled = false
        networkProvider.wirelessHardwareEnabled = true
        networkProvider.connected = false
        networkProvider.connectionName = ""
        networkProvider.lastRequest = false
        bluetoothProvider.powered = false
        bluetoothProvider.blocked = false
        bluetoothProvider.available = true
        bluetoothProvider.lastRequest = false
        storageFake.pending = false
        storageFake.lastOperation = ""
        storageFake.lastSuccess = false
        storageFake.lastError = ""
        storageFake.calls = []
    }
    function test_compactGroupsKeepSettingsNextToTheirControl(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        wait(0)
        const connectivity = findChild(view, "topBarConnectivitySection")
        const dnd = findChild(view, "topBarDndSection")
        const brightness = findChild(view, "topBarBrightnessSection")
        const volume = findChild(view, "topBarVolumeSection")
        verify(connectivity !== null && dnd !== null && brightness !== null && volume !== null)
        verify(connectivity.y < dnd.y)
        verify(dnd.y < brightness.y)
        verify(brightness.y < volume.y)
        verify(findChild(view, "topBarSettingsLinks") === null,
            "settings links must live beside their control, not in a footer")
        const spy = createTemporaryObject(spyComponent, test)
        spy.target = view
        spy.signalName = "settingsModuleRequested"
        findChild(view, "topBarWifiSettings").clicked()
        findChild(view, "topBarVolumeSettings").clicked()
        findChild(view, "topBarStorageSettings").clicked()
        compare(spy.count, 3)
        compare(spy.signalArguments[0][0], "network")
        compare(spy.signalArguments[1][0], "audio")
        compare(spy.signalArguments[2][0], "storage")
    }
    function test_doNotDisturbShowsTheEffectiveStateAndDelegatesSettings(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.dnd
        const row = findChild(view, "topBarDoNotDisturbControl")
        verify(row !== null)
        compare(control.available, true)
        compare(control.valid, true)
        compare(control.active, false)
        compare(control.statusText, "Off")
        notificationProvider.inhibited = true
        compare(control.active, true)
        compare(control.statusText, "On")
        // A service name alone is not a state: a pending or failed read never
        // appears as Off.
        notificationProvider.inhibited = false
        notificationProvider.reading = true
        notificationProvider.valid = false
        compare(control.active, false)
        compare(control.statusText, "Checking")
        notificationProvider.reading = false
        compare(control.statusText, "Unavailable")
        notificationProvider.valid = true
        const spy = createTemporaryObject(spyComponent, test)
        spy.target = view
        spy.signalName = "settingsModuleRequested"
        findChild(view, "topBarDoNotDisturbSettings").clicked()
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "notifications")
        notificationProvider.available = false
        compare(control.statusText, "Unavailable")
        compare(control.active, false)
    }
    function test_mediaShowsTheSelectedPlayerAndItsAnnouncedActions(): void {
        resetFakes()
        mediaProvider.players = [mediaPlayerA, mediaPlayerB]
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.media
        const media = findChild(view, "topBarMediaControl")
        verify(media !== null)
        compare(media.visible, true)
        compare(control.title, "Track A")
        compare(control.artist, "Artist A")
        const previous = findChild(view, "topBarMediaPrevious")
        const playPause = findChild(view, "topBarMediaPlayPause")
        const next = findChild(view, "topBarMediaNext")
        verify(previous !== null && playPause !== null && next !== null)
        compare(previous.enabled, false)
        compare(next.enabled, true)
        compare(playPause.Accessible.name, "Pause")
        next.clicked()
        compare(mediaPlayerA.nextCalls, 1)
        playPause.clicked()
        compare(mediaPlayerA.toggleCalls, 1)
        // An external pause changes the announced action, not just the icon.
        mediaPlayerA.isPlaying = false
        compare(control.playing, false)
        compare(playPause.Accessible.name, "Play")
        // A playing player wins over a paused first entry.
        mediaPlayerB.isPlaying = true
        mediaProvider.players = [mediaPlayerA, mediaPlayerB]
        compare(control.title, "Track B")
        compare(previous.enabled, true)
        previous.clicked()
        compare(mediaPlayerB.previousCalls, 1)
        // No player hides the whole section.
        notificationProvider.available = true
        notificationProvider.reading = false
        notificationProvider.valid = true
        notificationProvider.lastError = ""
        notificationProvider.inhibited = false
        mediaProvider.players = []
        compare(control.available, false)
        compare(media.visible, false)
    }
    function test_brightnessReflectsTheDisplayAndWritesThroughTheProvider(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.brightness
        const slider = findChild(view, "topBarBrightnessSlider")
        const value = findChild(view, "topBarBrightnessValue")
        verify(slider !== null && value !== null)
        compare(control.hasControl, true)
        compare(control.statusText, "Built-in display")
        compare(slider.value, 40)
        compare(value.text, "40%")
        slider.forceActiveFocus()
        keyClick(Qt.Key_Right)
        wait(0)
        compare(brightnessProvider.lastPercent, 41)
        // An external change flows back into the slider.
        brightnessProvider.displays = [{
            id: "display0", label: "Built-in display", internal: true,
            brightness: 7000, maximum: 10000, percent: 70
        }]
        compare(slider.value, 70)
        compare(value.text, "70%")
        // A display that changes under the gesture refuses the late value.
        control.beginGesture()
        brightnessProvider.displays = [{
            id: "display1", label: "External display", internal: false,
            brightness: 5000, maximum: 10000, percent: 50
        }]
        compare(control.setPercent(90), false)
        control.endGesture()
        // Removing the controllable display disables the slider explicitly.
        brightnessProvider.displays = []
        compare(control.hasControl, false)
        compare(control.statusText, "No controllable display")
        compare(slider.enabled, false)
    }
    function test_volumeReflectsTheProviderAndWritesOnlyWhileItIsReady(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const slider = findChild(view, "topBarVolumeSlider")
        const value = findChild(view, "topBarVolumeValue")
        verify(slider !== null && value !== null)
        compare(slider.value, 40)
        compare(value.text, "40%")
        slider.forceActiveFocus()
        keyClick(Qt.Key_Right)
        wait(0)
        fuzzyCompare(audioProvider.lastVolume, 0.41, 0.001)
        // An external change flows back into the slider.
        audioProvider.volume = 0.72
        compare(slider.value, 72)
        compare(value.text, "72%")
        // Mute is independent from volume.
        const mute = findChild(view, "topBarMute")
        mute.clicked()
        compare(audioProvider.lastMuted, true)
        compare(audioProvider.volume, 0.72)
        // A sink that changes during a drag refuses the late value.
        const audio = fakeControls.audio
        audio.beginGesture()
        audioProvider.nodeId = "sink-2"
        compare(audio.gestureStale, true)
        compare(audio.setPercent(90), false)
        verify(audioProvider.lastVolume !== 0.90)
        audio.endGesture()
    }
    function test_radioSwitchesStartFromTheProviderState(): void {
        resetFakes()
        networkProvider.wirelessEnabled = true
        networkProvider.connected = true
        networkProvider.connectionName = "Home"
        bluetoothProvider.powered = true
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        compare(findChild(view, "topBarWifiSwitch").checked, true)
        compare(findChild(view, "topBarBluetoothSwitch").checked, true)
    }
    function test_wifiSwitchShowsOnlyTheConfirmedState(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.network
        const toggle = findChild(view, "topBarWifiSwitch")
        verify(toggle !== null)
        compare(toggle.checked, false)
        toggle.checked = true
        compare(networkProvider.lastRequest, true)
        compare(control.pending, true)
        compare(control.statusText, "Applying")
        compare(toggle.checked, true)
        networkProvider.connected = true
        networkProvider.connectionName = "Home"
        networkProvider.wirelessEnabled = true
        networkProvider.changed()
        compare(control.pending, false)
        compare(control.errorCode, "")
        compare(control.statusText, "Home")
        // A hardware block keeps the action disabled and named.
        networkProvider.wirelessHardwareEnabled = false
        compare(control.actionEnabled, false)
        compare(control.statusText, "Radio blocked")
    }
    function test_wifiWithoutConfirmationKeepsTheProviderState(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.network
        control.confirmationTimer.interval = 80
        const toggle = findChild(view, "topBarWifiSwitch")
        toggle.checked = true
        compare(control.pending, true)
        tryCompare(control, "pending", false, 3000)
        compare(control.errorCode, "timeout")
        compare(control.statusText, "Not confirmed")
        compare(control.enabled, false)
        compare(toggle.checked, false)
    }
    function test_bluetoothShowsAdapterPresencePowerAndBlock(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const control = fakeControls.bluetooth
        const toggle = findChild(view, "topBarBluetoothSwitch")
        verify(toggle !== null)
        compare(control.adapterCount, 2)
        compare(control.statusText, "Off")
        const pair = findChild(view, "topBarBluetoothPair")
        verify(pair !== null)
        compare(pair.visible, false)
        toggle.checked = true
        compare(bluetoothProvider.lastRequest, true)
        bluetoothProvider.powered = true
        bluetoothProvider.changed()
        compare(control.pending, false)
        compare(control.statusText, "hci0")
        // Pairing is delegated to KDE's own wizard, never implemented here.
        compare(pair.visible, true)
        const spy = createTemporaryObject(spyComponent, test)
        spy.target = view
        spy.signalName = "bluetoothPairingRequested"
        pair.clicked()
        compare(spy.count, 1)
        bluetoothProvider.blocked = true
        compare(control.statusText, "Blocked")
        compare(control.actionEnabled, false)
        bluetoothProvider.available = false
        compare(control.statusText, "No adapter")
    }
    function test_storageListsEligibleVolumesAndAsksForTheExactOperation(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const card = findChild(view, "topBarStorageControl")
        verify(card !== null)
        compare(card.devices.length, 1)
        wait(10)
        compare(card.outcomeText, "")
        const remove = findChild(card, "topBarStorageRemove")
        const unmount = findChild(card, "topBarStorageUnmount")
        verify(remove !== null && unmount !== null)
        compare(remove.enabled, true)
        remove.clicked()
        compare(storageFake.calls[0], "remove:/org/freedesktop/UDisks2/drives/Test")
        compare(findChild(view, "topBarStorageOutcome").text, "Safe to remove")
        // Only the mounted volume offers unmounting.
        unmount.clicked()
        compare(storageFake.calls[1], "unmount:/org/freedesktop/UDisks2/block_devices/sdb1")
        compare(findChild(view, "topBarStorageOutcome").text, "Unmounted")
    }
    function test_storageProtectedMountDisablesWholeDriveRemoval(): void {
        resetFakes()
        storageFake.devices = [{
            id: "/org/freedesktop/UDisks2/drives/Test",
            name: "Test stick",
            volumes: [
                {path: "/org/freedesktop/UDisks2/block_devices/sdb1", label: "Photos", mounted: false, size: 1000}
            ],
            mountedCount: 1,
            protectedMounted: true,
            canRemove: false,
            ejectable: true
        }]
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const card = findChild(view, "topBarStorageControl")
        const remove = findChild(card, "topBarStorageRemove")
        verify(remove !== null)
        compare(remove.enabled, false)
        // The visible volume is unmounted, so it has no per-volume action.
        const unmount = findChild(card, "topBarStorageUnmount")
        verify(unmount !== null)
        compare(unmount.visible, false)
    }
    function test_storageBusyResultKeepsTheDeviceAndNamesTheFailure(): void {
        resetFakes()
        const view = createTemporaryObject(fixture, test)
        openControls(view)
        const card = findChild(view, "topBarStorageControl")
        verify(card !== null)
        storageFake.lastOperation = "remove"
        storageFake.lastTarget = "/org/freedesktop/UDisks2/drives/Test"
        storageFake.lastSuccess = false
        storageFake.lastError = "busy"
        compare(findChild(view, "topBarStorageOutcome").text, "Busy")
        storageFake.pending = true
        compare(findChild(card, "topBarStorageRemove").enabled, false)
        compare(findChild(card, "topBarStorageUnmount").enabled, false)
        // The device stays listed for a later attempt.
        compare(findChild(card, "topBarStorageDevice") !== null, true)
    }
}
