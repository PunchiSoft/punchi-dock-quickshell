#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the real Quickshell autostart service against temporary XDG state."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


FIXTURE = r'''import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: probe
    property int stage: 0
    property int ticks: 0

    function fail(message: string): void {
        console.error("AUTOSTART_FAILED " + message)
        Qt.exit(1)
    }

    AutostartService { id: autostart }
    FileView {
        id: entry
        path: autostart.path
        preload: true
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (++probe.ticks > 80) {
                probe.fail("timeout at stage " + probe.stage)
                return
            }
            if (probe.stage === 0) {
                if (Quickshell.env("PUNCHI_EXPECT_FOREIGN") === "1") {
                    if (autostart.available) {
                        probe.fail("foreign entry was treated as available")
                        return
                    }
                    autostart.begin()
                    autostart.draftEnabled = true
                    if (autostart.apply()) {
                        probe.fail("foreign entry was accepted")
                        return
                    }
                    console.warn("AUTOSTART_FOREIGN_PASSED")
                    Qt.exit(0)
                    return
                }
                if (!autostart.available || autostart.enabled) {
                    probe.fail("unexpected initial state")
                    return
                }
                autostart.begin()
                autostart.draftEnabled = true
                if (!autostart.apply()) {
                    probe.fail("enable was rejected")
                    return
                }
                probe.stage = 1
                return
            }
            if (probe.stage === 1) {
                if (!autostart.enabled) return
                entry.reload()
                const text = entry.text()
                if (text.indexOf("X-Punchi-Dock-Quickshell-Owned=true") < 0
                    || text.indexOf("OnlyShowIn=KDE;") < 0
                    || text.indexOf("X-KDE-autostart-phase=2") < 0
                    || text.indexOf("launcher.sh") < 0) {
                    probe.fail("owned entry content is incomplete: " + text)
                    return
                }
                console.warn("AUTOSTART_ENTRY " + text.replace(/\n/g, "\\n"))
                autostart.begin()
                autostart.draftEnabled = false
                if (!autostart.apply()) {
                    probe.fail("disable was rejected")
                    return
                }
                probe.stage = 2
                return
            }
            if (probe.stage === 2) {
                if (autostart.enabled) return
                console.warn("AUTOSTART_PASSED")
                Qt.exit(0)
            }
        }
    }
}
'''


def run_fixture(runner: str, root: Path, config_home: Path, expect_foreign: bool) -> str:
    environment = os.environ.copy()
    environment['XDG_CONFIG_HOME'] = str(config_home)
    if expect_foreign:
        environment['PUNCHI_EXPECT_FOREIGN'] = '1'
    else:
        environment.pop('PUNCHI_EXPECT_FOREIGN', None)
    result = subprocess.run([runner, '--path', str(root), '--no-color'], env=environment,
                            capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    print(output, end='')
    assert result.returncode == 0, output
    return output


def main() -> int:
    runner = sys.argv[1] if len(sys.argv) > 1 else shutil.which('qs')
    assert runner, 'Quickshell (qs) is required for the autostart runtime test'
    project = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-autostart-') as temporary:
        root = Path(temporary)
        (root / 'services').mkdir()
        shutil.copy2(project / 'services' / 'AutostartService.qml', root / 'services' / 'AutostartService.qml')
        (root / 'scripts-user').mkdir()
        launcher = root / 'scripts-user' / 'launcher.sh'
        launcher.write_text('#!/bin/sh\nexit 0\n')
        launcher.chmod(0o755)
        (root / 'assets' / 'icons').mkdir(parents=True)
        (root / 'assets' / 'icons' / 'punchi-dock-quickshell.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg"/>\n')
        (root / 'shell.qml').write_text('//@ pragma UseQApplication\n' + FIXTURE)

        config_home = root / 'config'
        config_home.mkdir()
        output = run_fixture(runner, root, config_home, False)
        assert 'AUTOSTART_PASSED' in output, output
        assert not (config_home / 'autostart' / 'punchi-dock-quickshell.desktop').exists()
        entry_match = re.search(r'AUTOSTART_ENTRY (.*)', output)
        assert entry_match, output
        entry = entry_match.group(1).replace('\\n', '\n')
        assert 'Exec="' + str(launcher) + '" start' in entry, entry
        assert 'Icon=' + str(root / 'assets' / 'icons' / 'punchi-dock-quickshell.svg') in entry, entry
        assert re.search(r'X-Punchi-Dock-Quickshell-Owned=true', entry), entry

        foreign_home = root / 'foreign-config'
        (foreign_home / 'autostart').mkdir(parents=True)
        foreign = foreign_home / 'autostart' / 'punchi-dock-quickshell.desktop'
        original = '[Desktop Entry]\nName=Another autostart entry\n'
        foreign.write_text(original)
        output = run_fixture(runner, root, foreign_home, True)
        assert 'AUTOSTART_FOREIGN_PASSED' in output, output
        assert foreign.read_text() == original

        empty_home = root / 'empty-config'
        (empty_home / 'autostart').mkdir(parents=True)
        empty = empty_home / 'autostart' / 'punchi-dock-quickshell.desktop'
        empty.write_text('')
        output = run_fixture(runner, root, empty_home, True)
        assert 'AUTOSTART_FOREIGN_PASSED' in output, output
        assert empty.read_text() == ''
        print('Autostart runtime: owned enable/disable and foreign-entry preservation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
