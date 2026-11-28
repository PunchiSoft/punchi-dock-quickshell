// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Quickshell
import "../config"
import "../adapters/kde"

// Services of the optional top panel. One instance serves every bar window so
// the clock, the provider clients and the pending-operation state stay shared.
// Every provider adapter is loaded only while the panel is enabled, so a shell
// that keeps the panel off never subscribes to PipeWire, NetworkManager, BlueZ
// or UDisks2, and disabling the switch releases them.
QtObject {
    id: root
    required property PunchiShellSettings settings
    readonly property bool active: root.settings.topBarEnabled
    // Minute precision: the clock only repaints when the shown text changes.
    readonly property SystemClock clock: SystemClock {
        enabled: root.active
        precision: SystemClock.Minutes
    }
    readonly property var brightnessProvider: brightnessLoader.item
    readonly property var audioProvider: audioLoader.item
    readonly property var networkProvider: networkLoader.item
    readonly property var bluetoothProvider: bluetoothLoader.item
    readonly property var storageProvider: storageLoader.item
    readonly property PunchiKdeToolAdapter tools: PunchiKdeToolAdapter {
        active: root.active
    }
    readonly property PunchiBrightnessControlService brightness: PunchiBrightnessControlService {
        provider: root.brightnessProvider
    }
    readonly property PunchiAudioControlService audio: PunchiAudioControlService {
        provider: root.audioProvider
    }
    readonly property PunchiNetworkControlService network: PunchiNetworkControlService {
        provider: root.networkProvider
    }
    readonly property PunchiBluetoothControlService bluetooth: PunchiBluetoothControlService {
        provider: root.bluetoothProvider
    }
    readonly property var storage: root.storageProvider
    function launchKRunner(): bool { return root.tools.launchKRunner() }
    function launchBluetoothWizard(): bool { return root.tools.launchBluetoothWizard() }
    function openSettingsModule(module: string): bool {
        return root.tools.openSettingsModule(module)
    }
    readonly property LazyLoader brightnessLoader: LazyLoader {
        active: root.active
        component: Component {
            PunchiBrightnessAdapter { active: true }
        }
    }
    readonly property LazyLoader audioLoader: LazyLoader {
        active: root.active
        component: Component {
            PunchiAudioAdapter { active: true }
        }
    }
    readonly property LazyLoader networkLoader: LazyLoader {
        active: root.active
        component: Component {
            PunchiNetworkAdapter { active: true }
        }
    }
    readonly property LazyLoader bluetoothLoader: LazyLoader {
        active: root.active
        component: Component {
            PunchiBluetoothAdapter { active: true }
        }
    }
    readonly property LazyLoader storageLoader: LazyLoader {
        active: root.active
        component: Component {
            PunchiStorageAdapter { active: true }
        }
    }
}
