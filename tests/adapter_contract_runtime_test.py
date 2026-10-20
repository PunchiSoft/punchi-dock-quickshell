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
    DesktopApplicationAdapter { id: application }
    ApplicationCatalogAdapter { id: catalog }
    ApplicationSearchAdapter { id: search }
    RecentDocumentsAdapter { id: recent }
    RecentApplicationsAdapter { id: recentApplications }
    RecentApplicationsSelection { id: recentApplicationsSelection }
    FilePlacesAdapter { id: places }
    ApplicationMediaAdapter { id: media }
    UserProfile { id: profile }
    MotionPreferences { id: motion }
    Component.onCompleted: Qt.callLater(function() {
        // Consumers: ApplicationLaunchService, ApplicationActivationService,
        // ApplicationContextService, TrashService, FolderNavigationController,
        // Dock.qml and the settings catalog projections.
        probe.checkMethods(application, "DesktopApplicationAdapter",
            ["launch", "actions", "launchAction", "canLaunchNewWindow", "openTrash",
             "openDownloads", "openFolderLocation", "openFolderPath", "openFolderUrl",
             "openPlace", "openRecent"])
        probe.checkProperties(application, "DesktopApplicationAdapter",
            ["applicationCount", "activationItem", "launchFinished"])
        probe.checkMethods(catalog, "ApplicationCatalogAdapter", ["get", "application"])
        probe.checkProperties(catalog, "ApplicationCatalogAdapter", ["count", "revision", "presets"])
        probe.checkProperties(search, "ApplicationSearchAdapter", ["sourceModel", "query", "count"])
        probe.checkMethods(recent, "RecentDocumentsAdapter", ["forget"])
        probe.checkProperties(recent, "RecentDocumentsAdapter", ["sourceModel", "desktopId", "count"])
        probe.checkMethods(recentApplications, "RecentApplicationsAdapter",
                            ["recordAccess", "setTrackingEnabled", "openTrackingSettings"])
        probe.checkProperties(recentApplications, "RecentApplicationsAdapter",
                            ["enabled", "available", "trackingEnabled"])
        probe.checkProperties(recentApplicationsSelection, "RecentApplicationsSelection",
            ["sourceModel", "enabled", "maximumItems", "excludedStorageIds", "count", "items"])
        probe.checkMethods(places, "FilePlacesAdapter", ["enterGroup", "leaveGroup"])
        probe.checkProperties(places, "FilePlacesAdapter",
            ["sourceModel", "desktopId", "count", "remainingCount", "showAll", "groupName"])
        probe.checkMethods(media, "ApplicationMediaAdapter", ["refresh"])
        probe.checkProperties(media, "ApplicationMediaAdapter",
            ["desktopId", "desktopEntry", "revision", "player", "players", "playing"])
        probe.checkProperties(profile, "UserProfile", ["displayName", "photoUrl", "avatarSource"])
        probe.checkProperties(motion, "MotionPreferences",
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
