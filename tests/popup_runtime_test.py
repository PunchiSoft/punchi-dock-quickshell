#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check icon-relative popup lifecycle without a compositor connection."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-popup-runtime-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import QtQuick.Controls
import "modules/dock"
ShellRoot {
    id: probe
    property int stage: 0
    property int configured: 0
    property int recentRequests: 0
    property int newRequests: 0
    property int unpinRequests: 0
    function reject(reason: string) { console.error("PUNCHI_POPUP_FAILED", reason); Qt.quit() }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 480
        implicitHeight: 320
        Item { id: icon; x: 200; y: 260; width: 40; height: 40 }
        PunchiDockContextPopup {
            id: menu
            hostWindow: host
            appId: "sentinel"
            onSettingsRequested: probe.configured++
            onActionRequested: function(appId, actionId) {
                if (!menu.visible || appId !== "sentinel" || actionId !== "sentinel-action") probe.reject("action wiring failed")
            }
            onRecentRequested: function(resource) {
                if (!menu.visible || resource !== "owned-document") probe.reject("recent activation lost input window")
                probe.recentRequests++
            }
            onNewWindowRequested: {
                if (!menu.visible) probe.reject("new window activation lost input window")
                probe.newRequests++
            }
            onUnpinRequested: {
                if (menu.visible) probe.reject("unpin happened before dismissal")
                probe.unpinRequests++
            }
        }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (probe.stage === 0) {
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 1) {
                if (!menu.opened || menu.sourceItem !== icon || menu.parent !== host.contentItem
                    || menu.popupType !== Popup.Item || menu.modal || menu.dim
                    || menu.mainItem.Window.window !== host.contentItem.Window.window
                    || Math.abs(menu.x + menu.width / 2 - 220) > 1
                    || menu.y + menu.height >= 260
                    || Math.abs(menu.x + menu.mainItem.pointerX - 220) > 1) {
                    probe.reject("modeless popup did not open at icon"); return
                }
                menu.mainItem.settingsRequested()
                if (menu.visible || probe.configured !== 1) { probe.reject("configure did not dismiss"); return }
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 2) {
                if (!menu.opened) { probe.reject("popup did not reopen"); return }
                menu.mainItem.actionRequested("sentinel-action")
                if (menu.visible) { probe.reject("action did not close popup"); return }
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 3) {
                if (!menu.opened) { probe.reject("popup did not reopen after action"); return }
                menu.mainItem.recentRequested("owned-document")
                if (menu.visible || probe.recentRequests !== 1) { probe.reject("recent did not dismiss"); return }
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 4) {
                if (!menu.opened) { probe.reject("popup did not reopen after recent"); return }
                menu.mainItem.newWindowRequested()
                if (menu.visible || probe.newRequests !== 1) { probe.reject("new window did not dismiss"); return }
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 5) {
                if (!menu.opened) { probe.reject("popup did not reopen after new window"); return }
                menu.mainItem.unpinRequested()
                if (menu.visible || probe.unpinRequests !== 1) { probe.reject("unpin did not dismiss"); return }
                menu.openForItem(icon, "Sentinel")
            } else if (probe.stage === 6) {
                if (!menu.opened) { probe.reject("popup did not reopen after unpin"); return }
                menu.mainItem.closeRequested()
                if (menu.visible) { probe.reject("popup did not close"); return }
                console.warn("PUNCHI_POPUP_PASSED")
                Qt.quit()
            }
            probe.stage++
        }
    }
}
''')
        environment = os.environ.copy()
        environment.pop('WAYLAND_DISPLAY', None)
        # The parent runner owns XDG state and cleans the entire process tree.
        result = subprocess.run(['qs', '--path', str(config), '--no-color'],
                                env=environment, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output, end='')
        forbidden = ('Cannot filter events for objects in a different thread',
                     'overrides a member of the base object', 'PUNCHI_POPUP_FAILED',
                     'Failed to load configuration', 'Unable to assign', 'ReferenceError', ' ERROR:')
        assert result.returncode == 0 and 'PUNCHI_POPUP_PASSED' in output, output
        assert not any(message in output for message in forbidden), output
    print('Popup icon-relative anchor, lifecycle, action wiring, and warning regressions: passed')


if __name__ == '__main__':
    main()
