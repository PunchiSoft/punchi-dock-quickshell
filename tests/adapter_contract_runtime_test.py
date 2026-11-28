#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the real adapter surface consumed by services, inside Quickshell.

The QML unit tests use mocks, so a service can call a method that the real
adapter never exposes without any test noticing. This probe instantiates every
real adapter that services and modules consume and checks the expected members
without invoking side-effecting actions such as opening the Trash or launching
applications.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-adapter-contract-') as directory:
        config = Path(directory)
        shutil.copytree(root / 'adapters', config / 'adapters')
        shutil.copytree(root / 'services', config / 'services')
        shutil.copytree(root / 'config', config / 'config')
        (config / 'shell.qml').write_text('''//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "adapters/kde"
import "services"
ShellRoot {
    id: probe
    property int failures: 0
    function fail(reason: string): void {
        probe.failures++
        console.error("PUNCHI_ADAPTER_CONTRACT_FAILED", reason)
    }
    function checkMethods(owner, name, methods) {
        for (const method of methods)
            if (typeof owner[method] !== "function") probe.fail(name + "." + method + " is not callable")
    }
    function checkProperties(owner, name, properties) {
        for (const property of properties)
            if (!(property in owner)) probe.fail(name + "." + property + " is missing")
    }
    PunchiDesktopApplicationAdapter { id: application }
    PunchiApplicationCatalogAdapter { id: catalog }
    PunchiApplicationSearchAdapter { id: search }
    PunchiRecentDocumentsAdapter { id: recent }
    PunchiRecentApplicationsAdapter { id: recentApplications }
    PunchiRecentApplicationsSelection { id: recentApplicationsSelection }
    PunchiFilePlacesAdapter { id: places }
    PunchiApplicationMediaAdapter { id: media }
    PunchiUserProfile { id: profile }
    PunchiMotionPreferences { id: motion }
    PunchiNetworkAdapter { id: network }
    PunchiBluetoothAdapter { id: bluetooth }
    PunchiStorageAdapter { id: storage }
    PunchiBrightnessAdapter { id: brightness }
    PunchiAudioControlService { id: audioControl }
    PunchiKdeToolAdapter { id: tools }
    Component.onCompleted: Qt.callLater(function() {
        // Consumers: PunchiApplicationLaunchService, PunchiApplicationActivationService,
        // PunchiApplicationContextService, PunchiTrashService, PunchiFolderNavigationController,
        // PunchiDock.qml and the settings catalog projections.
        probe.checkMethods(application, "PunchiDesktopApplicationAdapter",
            ["launch", "actions", "launchAction", "canLaunchNewWindow", "openTrash",
             "openDownloads", "openHome", "openFolderLocation", "openFolderPath", "openFolderUrl",
             "openPlace", "openRecent"])
        probe.checkProperties(application, "PunchiDesktopApplicationAdapter",
            ["applicationCount", "activationItem", "launchFinished"])
        probe.checkMethods(catalog, "PunchiApplicationCatalogAdapter", ["get", "application"])
        probe.checkProperties(catalog, "PunchiApplicationCatalogAdapter", ["count", "revision", "presets"])
        // The fullscreen menu groups rows by the desktop entry's categories, so
        // the map a consumer reads must carry that member.
        if (catalog.count > 0)
            probe.checkProperties(catalog.get(0), "PunchiApplicationCatalogAdapter.get(0)", ["categories"])
        probe.checkProperties(search, "PunchiApplicationSearchAdapter", ["sourceModel", "query", "count"])
        probe.checkMethods(recent, "PunchiRecentDocumentsAdapter", ["forget"])
        probe.checkProperties(recent, "PunchiRecentDocumentsAdapter", ["sourceModel", "desktopId", "count"])
        probe.checkMethods(recentApplications, "PunchiRecentApplicationsAdapter",
                            ["recordAccess", "setTrackingEnabled", "openTrackingSettings"])
        probe.checkProperties(recentApplications, "PunchiRecentApplicationsAdapter",
                            ["enabled", "available", "trackingEnabled"])
        probe.checkProperties(recentApplicationsSelection, "PunchiRecentApplicationsSelection",
            ["sourceModel", "enabled", "maximumItems", "excludedStorageIds", "count", "items"])
        probe.checkMethods(places, "PunchiFilePlacesAdapter", ["enterGroup", "leaveGroup", "acceptsUrl"])
        probe.checkProperties(places, "PunchiFilePlacesAdapter",
            ["sourceModel", "desktopId", "count", "remainingCount", "showAll", "groupName"])
        probe.checkMethods(media, "PunchiApplicationMediaAdapter", ["refresh"])
        probe.checkProperties(media, "PunchiApplicationMediaAdapter",
            ["desktopId", "desktopEntry", "revision", "player", "players", "playing"])
        probe.checkProperties(profile, "PunchiUserProfile", ["displayName", "photoUrl", "avatarSource"])
        probe.checkProperties(motion, "PunchiMotionPreferences",
            ["reducedMotion", "clickDuration", "enterDuration", "leaveDuration", "slideDuration"])
        // Top panel providers. Only the contract is read; every action method
        // stays uncalled so the probe cannot change audio, radio or storage.
        // The audio provider is Quickshell's PipeWire service. Creating it
        // requires a live PipeWire socket, which this isolated probe does not
        // own, so its contract runs in tst_topbar_controls with a provider
        // double; the control service is checked here.
        probe.checkMethods(audioControl, "PunchiAudioControlService",
            ["setPercent", "toggleMute", "beginGesture", "endGesture"])
        probe.checkProperties(audioControl, "PunchiAudioControlService",
            ["available", "ready", "description", "volume", "percent", "muted",
             "maximumPercent", "gestureStale"])
        probe.checkMethods(network, "PunchiNetworkAdapter", ["setWirelessEnabled"])
        probe.checkProperties(network, "PunchiNetworkAdapter",
            ["available", "wirelessEnabled", "wirelessHardwareEnabled", "connected", "connectionName"])
        probe.checkMethods(bluetooth, "PunchiBluetoothAdapter", ["setPowered"])
        probe.checkProperties(bluetooth, "PunchiBluetoothAdapter",
            ["available", "adapterCount", "adapterName", "powered", "blocked"])
        probe.checkMethods(brightness, "PunchiBrightnessAdapter", ["refresh", "setPercent"])
        probe.checkProperties(brightness, "PunchiBrightnessAdapter",
            ["available", "displays", "pending", "lastTarget", "lastPercent",
             "lastSuccess", "lastError"])
        probe.checkMethods(storage, "PunchiStorageAdapter",
            ["refresh", "unmountVolume", "removeDrive"])
        probe.checkProperties(storage, "PunchiStorageAdapter",
            ["available", "devices", "pending", "lastOperation", "lastTarget", "lastSuccess", "lastError"])
        probe.checkMethods(tools, "PunchiKdeToolAdapter",
            ["launchKRunner", "launchBluetoothWizard", "openSettingsModule", "settingsModuleId"])
        probe.checkProperties(tools, "PunchiKdeToolAdapter", ["active"])
        if (probe.failures === 0) {
            console.warn("PUNCHI_ADAPTER_CONTRACT_OK")
            Qt.quit()
        } else {
            Qt.quit()
        }
    })
}
''')
        env = os.environ.copy()
        env.pop('QT_QUICK_CONTROLS_STYLE', None)
        env.pop('WAYLAND_DISPLAY', None)
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        # The private session bus has no NetworkManager or BlueZ. Quickshell's
        # providers log that absence while the probe only checks adapter members;
        # keep those categories quiet so a real contract error still fails.
        env['QT_LOGGING_RULES'] = ('quickshell.network=false;'
                                   'quickshell.dbus.objectmanager=false')
        result = subprocess.run(['qs', '-p', str(config / 'shell.qml'), '--no-duplicate',
                                 '--no-color'],
                                env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0
        assert 'PUNCHI_ADAPTER_CONTRACT_OK' in output
        assert 'PUNCHI_ADAPTER_CONTRACT_FAILED' not in output
        unexpected = '\n'.join(line for line in output.splitlines()
                               if 'PUNCHI_ADAPTER_CONTRACT_OK' not in line)
        assert not any(marker in unexpected for marker in ('WARN', 'Warning:', 'ERROR', 'Error:'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
