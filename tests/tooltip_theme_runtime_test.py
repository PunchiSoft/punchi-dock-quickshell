#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Match the production tooltip and menu while Kirigami colors change on a private bus."""
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

import dbus
from PIL import Image


def main():
    root = Path(__file__).resolve().parents[1]
    # Explicit development-only evidence; the normal test leaves no artifacts.
    captures = Path(tempfile.mkdtemp(prefix='tooltip-theme-preview-', dir=root / 'notes/reviews')) \
        if sys.argv[1:] == ['--capture'] else None
    with tempfile.TemporaryDirectory(prefix='punchi-tooltip-theme-') as temporary:
        owned = Path(temporary)
        for name in ('components', 'config', 'adapters', 'modules', 'services'):
            shutil.copytree(root / name, owned / name)
        fixture = (root / 'tests/runtime/tooltip-theme/shell.qml').read_text()
        (owned / 'shell.qml').write_text(fixture.replace('../../../', ''))
        images = owned / 'images'
        images.mkdir()
        data = owned / 'data'
        settings = owned / 'settings'
        settings.mkdir()
        themes = {
            'owned-light': ('#e7f2d9', '#223311'),
            'owned-dark': ('#142d46', '#ecf4fb'),
        }
        globals_file = settings / 'kdeglobals'

        def write_palette(name):
            background, foreground = themes[name]
            globals_file.write_text(
                '[General]\nfont=Sans Serif,11,-1,5,50,0,0,0,0,0\n'
                f'[Colors:Window]\nBackgroundNormal={background}\nForegroundNormal={foreground}\n'
                '[Colors:Tooltip]\nBackgroundNormal=255,238,0\nForegroundNormal=153,0,153\n')

        write_palette('owned-light')
        env = os.environ.copy()
        env.update(XDG_CONFIG_HOME=str(settings), XDG_DATA_HOME=str(data),
                   QT_QPA_PLATFORMTHEME='kde', QT_NO_XDG_DESKTOP_PORTAL='1',
                   PUNCHI_TOOLTIP_IMAGES=str(images))
        env.pop('WAYLAND_DISPLAY', None)
        env.pop('QT_QUICK_CONTROLS_STYLE', None)
        process = subprocess.Popen(['qs', '--path', str(owned), '--no-color'], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        lines = queue.Queue()
        output = []

        def read():
            for line in process.stdout:
                output.append(line)
                lines.put(line)
            lines.put(None)

        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        try:
            bus = dbus.SessionBus()
            for stage, name in enumerate(('owned-light', 'owned-dark', 'owned-light')):
                if stage:
                    write_palette(name)
                    message = dbus.lowlevel.SignalMessage('/KGlobalSettings', 'org.kde.KGlobalSettings', 'notifyChange')
                    message.append(dbus.Int32(0), dbus.Int32(0), signature='ii')
                    bus.send_message(message)
                deadline = time.monotonic() + 5
                matched = False
                while time.monotonic() < deadline:
                    try:
                        line = lines.get(timeout=0.3)
                    except queue.Empty:
                        continue
                    if line is None:
                        raise AssertionError('Quickshell exited before the tooltip theme check.')
                    match = re.search(r'PUNCHI_TOOLTIP_FRAME (\{.*\})', line)
                    if not match:
                        continue
                    snapshot = json.loads(match[1])
                    file = images / f"{snapshot['frame']}.png"
                    background, foreground = themes[name]
                    if snapshot['background'] == background and snapshot['text'] == foreground:
                        assert snapshot['menuBackground'] == background
                        assert snapshot['menuText'] == foreground
                        assert snapshot['menuBorder'] == snapshot['border']
                        assert snapshot['border'] not in ('#abcdef', background)
                        assert snapshot['font'] == 'Sans Serif'
                        with Image.open(file) as image:
                            pixels = image.convert('RGBA')
                            expected = tuple(bytes.fromhex(background[1:])) + (255,)
                            assert pixels.getpixel((image.width // 2, image.height // 3)) == expected
                            assert pixels.getpixel((image.width // 2, image.height - 3)) == expected
                            assert pixels.getpixel((0, image.height - 3))[3] == 0
                        if captures:
                            shutil.copy2(file, captures / f'{stage}-{name}.png')
                        matched = True
                    file.unlink()
                    if matched:
                        print(f'Kirigami tooltip stage {stage}: {name}, matching menu colors and preserved balloon.')
                        break
                assert matched, f'Tooltip did not adopt {name}.'
        except Exception:
            print(''.join(output))
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join(timeout=2)
        unexpected = [line for line in output if re.search(r'\bWARN\b|\bERROR\b', line)
                      and not re.search(r'\bWARN.*PUNCHI_TOOLTIP_FRAME ', line)]
        assert not unexpected, ''.join(unexpected)
    if captures:
        print(f'Owned preview evidence: {captures}')
    print('Kirigami tooltip: matching menu colors, live KDE palette notifications, font and balloon pixels passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
