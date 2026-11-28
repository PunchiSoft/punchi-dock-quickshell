// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import Punchi.Kde as Native

// The complementary KDE entry points of the panel: KRunner and the settings
// modules that own configuration Punchi does not implement. Every target is a
// fixed identifier; the native side launches it with an argument list, never
// through a shell.
QtObject {
    id: root
    property bool active: false
    readonly property Native.KdeToolLauncher launcher: Native.KdeToolLauncher {}
    function launchKRunner(): bool { return root.launcher.launchKRunner() }
    function launchBluetoothWizard(): bool { return root.launcher.launchBluetoothWizard() }
    function settingsModuleId(module: string): string {
        switch (module) {
        case "network": return "kcm_networkmanagement"
        case "bluetooth": return "kcm_bluetooth"
        case "audio": return "kcm_pulseaudio"
        case "storage": return "kcm_device_automounter"
        }
        return ""
    }
    function openSettingsModule(module: string): bool {
        const id = root.settingsModuleId(module)
        return id.length > 0 && root.launcher.openSettingsModule(id)
    }
}
