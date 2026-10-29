#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Load the actual KDE-styled confirmation in QS with owned fake operations."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-trash-ui-') as directory:
        config = Path(directory)
        for name in ('modules', 'components', 'services', 'config', 'adapters'):
            shutil.copytree(root / name, config / name)
        (config / 'shell.qml').write_text('''//@ pragma UseQApplication
//@ pragma RespectSystemStyle
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Punchi.Kde as Native
import "services"
import "modules/dock"
import "adapters/kde"
ShellRoot {
    id: probe
    property int stage: 0
    property int ticks: 0
    function reject(reason: string): void { console.error("PUNCHI_TRASH_FAILED", reason); Qt.quit() }
    Native.DockItemCatalog { id: items }
    PunchiPinnedApplications { id: dockPins; catalog: items; pinnedIds: ["item:trash"] }
    PunchiPinnedApplications { id: settingsPins; catalog: items; pinnedIds: ["item:trash"] }
    QtObject {
        id: state
        property bool available: true
        property bool hasItems: true
        property bool busy: false
        property int emptyCalls: 0
        function emptyAfterConfirmation(): bool { emptyCalls++; return true }
    }
    QtObject { id: launch; function openTrash(): bool { return true } }
    PunchiTrashService { id: trash; state: state; launcher: launch }
    // The fake launcher proves PunchiTrashService behavior; the real adapter guards
    // the method surface PunchiDock.qml injects. Never invoke it here: openTrash()
    // would launch the user's file manager.
    PunchiDesktopApplicationAdapter { id: realLauncher }
    PunchiTrashService { id: realTrash; state: state; launcher: realLauncher }
    Window { visible: true; width: 480; height: 320 }
    PunchiTrashConfirmationWindow {
        id: confirmation
        service: trash
        questionText: "Owned confirmation question"
        warningText: "Owned confirmation warning"
    }
    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            if (++probe.ticks > 40) { probe.reject("confirmation timed out"); return }
            if (probe.stage === 0) {
                if (typeof dockPins.get(0).title !== "string" || typeof settingsPins.get(0).title !== "string") {
                    probe.reject("initial item title was undefined"); return
                }
                items.trashTitle = "Owned Trash"
                if (dockPins.get(0).title !== "Owned Trash" || settingsPins.get(0).title !== "Owned Trash") {
                    probe.reject("late item title did not reach both projections"); return
                }
                if (typeof realLauncher.openTrash !== "function" || typeof realTrash.open !== "function") {
                    probe.reject("real adapter is missing the PunchiTrashService entry point"); return
                }
                if (!trash.requestEmpty()) { probe.reject("request refused"); return }
                probe.stage++
            } else if (probe.stage === 1) {
                if (!confirmation.visible) return
                if (confirmation.width <= 0 || confirmation.height <= 0 || state.emptyCalls !== 0) {
                    probe.reject("confirmation geometry or cancellation contract failed"); return
                }
                confirmation.close()
                if (!confirmation.visible || trash.confirming) { probe.reject("close skipped exit"); return }
                trash.requestEmpty()
                probe.stage++
            } else if (probe.stage === 2) {
                if (!confirmation.visible || !trash.confirming) { probe.reject("close reversal lost window"); return }
                trash.cancel()
                probe.stage++
            } else if (probe.stage === 3) {
                if (confirmation.visible) return
                confirmation.reducedMotion = true
                trash.requestEmpty()
                if (!confirmation.visible) { probe.reject("reduced motion failed"); return }
                if (!trash.confirm() || trash.confirming || confirmation.visible || state.emptyCalls !== 1) {
                    probe.reject("explicit acceptance failed"); return
                }
                console.warn("PUNCHI_TRASH_OK")
                Qt.quit()
            }
        }
    }
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
        assert result.returncode == 0 and 'PUNCHI_TRASH_OK' in output and 'PUNCHI_TRASH_FAILED' not in output
        unexpected = '\n'.join(line for line in output.splitlines() if 'PUNCHI_TRASH_OK' not in line)
        assert not any(marker in unexpected for marker in ('WARN', 'Warning:', 'ERROR', 'Error:'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
