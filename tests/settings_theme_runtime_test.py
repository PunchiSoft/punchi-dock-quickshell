#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Load the real settings window with KDE controls and owned color schemes."""
import os
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    pragmas = '\n'.join(line for line in (root / 'shell.qml').read_text().splitlines()
                        if line.startswith('//@ pragma '))
    with tempfile.TemporaryDirectory(prefix='punchi-settings-theme-') as temporary:
        config = Path(temporary)
        for name in ('modules', 'components', 'config', 'services', 'adapters'):
            shutil.copytree(root / name, config / name)
        fixture = '''import QtQuick
import Quickshell
import org.kde.kirigami as Kirigami
import "modules/settings"
import "config"
import "services"
ShellRoot {
    id: probe
    property int stage: 0
    property int lastFrames: 0
    property int frames: 0
    property int ticks: 0
    function find(item: var, name: string): var {
        if (item.objectName === name) return item
        const children = item.data || item.children
        if (!children) return null
        for (let i = 0; i < children.length; ++i) {
            const found = find(children[i], name)
            if (found) return found
        }
        return null
    }
    ShellSettings { id: preferences }
    ApplicationCatalog { id: applications }
    SettingsStore { id: store; settings: preferences }
    SettingsWindow { id: window; settings: preferences; applicationCatalog: applications; onFrameSwapped: probe.frames++ }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (probe.stage === 1) {
                if (window.visible && probe.frames > probe.lastFrames
                    && !probe.find(window.contentItem, "dockSettingsView").addingApplication) {
                    const view = probe.find(window.contentItem, "dockSettingsView")
                    if (window.hasPendingChanges || view.settings.sizePercent !== 100
                        || view.settings.magnificationEnabled || view.settings.bounceEnabled) {
                        console.error("PUNCHI_THEME_FAILED cancelled edits survived reopen"); Qt.quit(); return
                    }
                    console.warn("PUNCHI_THEME_PASSED")
                    Qt.quit()
                }
                if (++probe.ticks > 30) { console.error("PUNCHI_THEME_FAILED editor did not settle"); Qt.quit() }
                return
            }
            if (++probe.ticks === 1) { window.open(); return }
            if (!window.visible || probe.frames < 1 || !store.ready) {
                if (probe.ticks > 30) { console.error("PUNCHI_THEME_FAILED no settings frame"); Qt.quit() }
                return
            }
            const view = probe.find(window.contentItem, "dockSettingsView")
            const toggle = probe.find(window.contentItem, "magnification")
            const expected = Quickshell.env("PUNCHI_EXPECT_WINDOW_COLOR")
            if (!view || !toggle || !Qt.colorEqual(window.color, expected)
                || !Qt.colorEqual(view.palette.window, expected)
                || !Qt.colorEqual(view.Kirigami.Theme.backgroundColor, expected)
                || view.font.family !== Kirigami.Theme.defaultFont.family
                || toggle.font.family !== view.font.family) {
                console.error("PUNCHI_THEME_FAILED palette/font", window.color, view ? view.palette.window : "no view")
                Qt.quit(); return
            }
            preferences.magnificationEnabled = false
            if (toggle.checked || probe.find(window.contentItem, "zoomScale").enabled) {
                console.error("PUNCHI_THEME_FAILED settings binding"); Qt.quit(); return
            }
            view.settings.bounceEnabled = false
            probe.find(view, "applyDockSettings").clicked()
            if (preferences.bounceEnabled || window.hasPendingChanges || !window.visible) {
                console.error("PUNCHI_THEME_FAILED Apply"); Qt.quit(); return
            }
            view.settings.sizePercent = 125
            view.settings.magnificationEnabled = true
            if (!window.hasPendingChanges || preferences.sizePercent !== 100
                || preferences.magnificationEnabled) {
                console.error("PUNCHI_THEME_FAILED pending edits leaked"); Qt.quit(); return
            }
            view.currentPage = 0
            probe.find(view, "addDockApplication").clicked()
            const dialog = probe.find(view, "addApplicationDialog")
            if (!dialog || !dialog.visible || dialog.width <= 0 || dialog.height <= 0
                || dialog.contentItem.Window.window !== window) {
                console.error("PUNCHI_THEME_FAILED editor host"); Qt.quit(); return
            }
            dialog.selectionRequested("files")
            window.close()
            if (dialog.controller.selectedAppId !== "") {
                console.error("PUNCHI_THEME_FAILED draft survived close"); Qt.quit(); return
            }
            if (window.visible) { console.error("PUNCHI_THEME_FAILED close"); Qt.quit(); return }
            probe.lastFrames = probe.frames
            window.open()
            if (!window.visible) { console.error("PUNCHI_THEME_FAILED reopen"); Qt.quit(); return }
            probe.stage = 1
        }
    }
}
'''
        (config / 'shell.qml').write_text(pragmas + '\n' + fixture)
        for name, background, foreground, override in (
            ('dark', '25,35,45', '232,236,240', None),
            ('light', '240,245,250', '25,35,45', None),
            ('override', '25,35,45', '232,236,240', 'Fusion'),
        ):
            home = config / name
            home.mkdir()
            view_background = '255,255,255' if name == 'light' else '50,60,70'
            (home / 'kdeglobals').write_text(f'[Colors:Window]\nBackgroundNormal={background}\nForegroundNormal={foreground}\n'
                f'[Colors:View]\nBackgroundNormal={view_background}\nForegroundNormal={foreground}\n')
            environment = os.environ.copy()
            environment['XDG_CONFIG_HOME'] = str(home)
            environment['QT_QPA_PLATFORMTHEME'] = 'kde'
            environment['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
            environment['QT_LOGGING_RULES'] = 'qt.quick.controls.style.debug=true'
            environment['PUNCHI_EXPECT_WINDOW_COLOR'] = '#'+''.join(f'{int(n):02x}' for n in background.split(','))
            environment.pop('WAYLAND_DISPLAY', None)
            environment.pop('QT_QUICK_CONTROLS_STYLE', None)
            if override:
                environment['QT_QUICK_CONTROLS_STYLE'] = override
            try:
                result = subprocess.run(['qs', '--path', str(config), '--no-color'], env=environment,
                                        capture_output=True, text=True, timeout=9)
            except subprocess.TimeoutExpired as error:
                print((error.stdout or b'').decode(errors='replace'), (error.stderr or b'').decode(errors='replace'))
                raise
            output = result.stdout + result.stderr
            print(f'Theme fixture: {name}\n{output}', end='')
            assert result.returncode == 0 and 'PUNCHI_THEME_PASSED' in output, output
            assert not re.search(r'\bERROR\b|PUNCHI_THEME_FAILED|ReferenceError|TypeError|Binding loop|'
                r'without a QApplication|Unrecognized pragma|different thread|overrides a member|Unable to assign|at engine destruction', output), output
            expected_style = override or 'org.kde.desktop'
            selected = re.findall(r'qt.quick.controls.style: done resolving:\s*style="([^"]+)"', output)
            assert selected and selected[-1] == expected_style, output
            saved = json.loads((home / 'punchi-shell.json').read_text())
            assert saved['sizePercent'] == 100 and saved['magnificationEnabled'] is False, saved
            assert saved['bounceEnabled'] is False, saved
        print('KDE settings theme: owned light/dark palettes, native style discovery, explicit style override and window lifecycle passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
