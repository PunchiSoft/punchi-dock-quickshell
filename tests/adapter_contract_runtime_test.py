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
        (config / 'shell.qml').write_text('''//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "adapters/kde"
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
        probe.checkProperties(search, "PunchiApplicationSearchAdapter", ["sourceModel", "query", "count"])
        probe.checkMethods(recent, "PunchiRecentDocumentsAdapter", ["forget"])
        probe.checkProperties(recent, "PunchiRecentDocumentsAdapter", ["sourceModel", "desktopId", "count"])
        probe.checkMethods(recentApplications, "PunchiRecentApplicationsAdapter",
                            ["recordAccess", "setTrackingEnabled", "openTrackingSettings"])
        probe.checkProperties(recentApplications, "PunchiRecentApplicationsAdapter",
                            ["enabled", "available", "trackingEnabled"])
        probe.checkProperties(recentApplicationsSelection, "PunchiRecentApplicationsSelection",
            ["sourceModel", "enabled", "maximumItems", "excludedStorageIds", "count", "items"])
        probe.checkMethods(places, "PunchiFilePlacesAdapter", ["enterGroup", "leaveGroup"])
        probe.checkProperties(places, "PunchiFilePlacesAdapter",
            ["sourceModel", "desktopId", "count", "remainingCount", "showAll", "groupName"])
        probe.checkMethods(media, "PunchiApplicationMediaAdapter", ["refresh"])
        probe.checkProperties(media, "PunchiApplicationMediaAdapter",
            ["desktopId", "desktopEntry", "revision", "player", "players", "playing"])
        probe.checkProperties(profile, "PunchiUserProfile", ["displayName", "photoUrl", "avatarSource"])
        probe.checkProperties(motion, "PunchiMotionPreferences",
            ["reducedMotion", "clickDuration", "enterDuration", "leaveDuration", "slideDuration"])
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
        result = subprocess.run(['qs', '-p', str(config / 'shell.qml'), '--no-duplicate'],
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
