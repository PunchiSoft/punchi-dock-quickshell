#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify settings persistence and window lifecycle in an isolated Wayland session."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def run_shell(config, env):
    try:
        return subprocess.run(['qs', '--path', str(config), '--no-color'], env=env,
                              capture_output=True, text=True, timeout=6)
    except subprocess.TimeoutExpired as error:
        print(error.stdout, error.stderr, file=sys.stderr)
        raise


def main():
    root = Path(__file__).resolve().parents[1]
    if '--isolated' not in sys.argv:
        return subprocess.run([sys.executable, str(root / 'scripts-dev/run-isolated.py'),
            '--session', '--', sys.executable, str(Path(__file__).resolve()), '--isolated']).returncode
    with tempfile.TemporaryDirectory(prefix='punchi-shell-settings-') as temporary:
        config = Path(temporary)
        for directory in ('components', 'config', 'services', 'modules', 'adapters', 'assets'):
            shutil.copytree(root / directory, config / directory)
        fixture = '''import QtQuick
import Quickshell
import "modules/dock"
import "modules/settings"
import "services"
ShellRoot {
    Dock { id: dock; onSettingsRequested: window.open() }
    SettingsStore { id: store; settings: dock.preferences }
    SettingsWindow { id: window; settings: dock.preferences; onFrameSwapped: frames += 1 }
    property int frames: 0
    Timer {
        interval: 300; running: true; repeat: false
        onTriggered: {
            if (!store.ready) throw new Error("Settings did not load")
            if (Quickshell.env("PUNCHI_TEST_RESTORE") === "1") {
                if (dock.preferences.panelMode !== "dodge-windows" || dock.preferences.sizePercent !== 125
                    || dock.preferences.pinnedIds.join(",") !== "terminal,files")
                    throw new Error("Preferences did not survive restart")
            } else if (Quickshell.env("PUNCHI_TEST_MIGRATE") !== "1") {
                dock.preferences.panelMode = "desktop"
                dock.preferences.sizePercent = 125
                dock.preferences.pinnedIds = ["terminal", "files"]
            }
            dock.settingsRequested()
        }
    }
    Timer {
        interval: 900; running: true; repeat: false
        onTriggered: {
            if (!window.visible || frames === 0) throw new Error("Settings window did not render")
            window.close()
            if (window.visible || !dock.visible) throw new Error("Closing settings hid the dock")
            window.open()
            console.warn("PUNCHI_SETTINGS_PASS")
            Qt.quit()
        }
    }
}
'''
        (config / 'shell.qml').write_text(fixture)
        env = os.environ.copy()
        env['XDG_CONFIG_HOME'] = str(config / 'preferences')
        Path(env['XDG_CONFIG_HOME']).mkdir()
        env.pop('PUNCHI_DOCK_MODE', None)
        for restore in ('0', '1'):
            env['PUNCHI_TEST_RESTORE'] = restore
            result = run_shell(config, env)
            output = result.stdout + result.stderr
            if result.returncode or 'PUNCHI_SETTINGS_PASS' not in output or re.search(
                    r'TypeError|ReferenceError|Binding loop|Failed to load|\bERROR\b', output):
                raise RuntimeError(output)
            data = json.loads((Path(env['XDG_CONFIG_HOME']) / 'punchi-dock-quickshell.json').read_text())
            assert data['panelMode'] == 'dodge-windows' and data['sizePercent'] == 125, data
            assert data['pinnedIds'] == ['terminal', 'files'], data
        # A legacy profile is copied only when the new location is absent.
        preferences = Path(env['XDG_CONFIG_HOME'])
        current = preferences / 'punchi-dock-quickshell.json'
        legacy = preferences / 'punchi-shell.json'
        current.unlink()
        migrated = json.loads((preferences / 'punchi-dock-quickshell.json').read_text()) \
            if current.exists() else data
        migrated['sizePercent'] = 130
        legacy.write_text(json.dumps(migrated))
        env['PUNCHI_TEST_RESTORE'] = '0'
        env['PUNCHI_TEST_MIGRATE'] = '1'
        result = run_shell(config, env)
        output = result.stdout + result.stderr
        if result.returncode or 'PUNCHI_SETTINGS_PASS' not in output:
            raise RuntimeError(output)
        assert json.loads(current.read_text())['sizePercent'] == 130
        assert json.loads(legacy.read_text())['sizePercent'] == 130
        current.write_text(json.dumps({**migrated, 'sizePercent': 140}))
        legacy.write_text(json.dumps({**migrated, 'sizePercent': 110}))
        result = run_shell(config, env)
        output = result.stdout + result.stderr
        if result.returncode or 'PUNCHI_SETTINGS_PASS' not in output:
            raise RuntimeError(output)
        assert json.loads(current.read_text())['sizePercent'] == 140
        assert json.loads(legacy.read_text())['sizePercent'] == 110
        # Malformed files fall back safely instead of preventing shell startup.
        current.write_text('{invalid')
        env['PUNCHI_TEST_RESTORE'] = '0'
        env.pop('PUNCHI_TEST_MIGRATE', None)
        result = run_shell(config, env)
        assert result.returncode == 0 and 'PUNCHI_SETTINGS_PASS' in result.stdout + result.stderr
        print('Wayland settings open/close/reopen, dock coexistence, persistence and malformed JSON: passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
