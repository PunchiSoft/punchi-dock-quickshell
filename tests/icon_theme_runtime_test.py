#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render unchanged production icons while KDE changes owned themes on a private bus."""
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import tempfile
import threading
import time

from PIL import Image


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='punchi-icon-theme-') as directory:
        owned = Path(directory)
        for name in ('components', 'config', 'modules', 'services', 'adapters'):
            shutil.copytree(root / name, owned / name)
        fixture = (root / 'tests/runtime/icon-theme/shell.qml').read_text()
        (owned / 'shell.qml').write_text(fixture.replace('../../../', ''))
        images = owned / 'images'
        images.mkdir()
        data = owned / 'data'
        config = owned / 'settings'
        config.mkdir()
        colors = {'owned-red': (222, 33, 44), 'owned-green': (22, 199, 66)}
        for theme, color in colors.items():
            icons = data / 'icons' / theme / 'scalable/apps'
            icons.mkdir(parents=True)
            (icons.parent.parent / 'index.theme').write_text(
                f'[Icon Theme]\nName={theme}\nDirectories=scalable/apps\nInherits=hicolor\n'
                '[scalable/apps]\nSize=64\nType=Scalable\nMinSize=1\nMaxSize=512\nContext=Applications\n')
            for name in ('owned-app', 'user-trash', 'user-trash-full'):
                (icons / f'{name}.svg').write_text(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">'
                    f'<rect width="64" height="64" fill="rgb{color}"/></svg>')
        globals_file = config / 'kdeglobals'
        globals_file.write_text('[Icons]\nTheme=owned-red\n')
        env = os.environ.copy()
        env['XDG_CONFIG_HOME'] = str(config)
        env['XDG_DATA_HOME'] = str(data)
        env['QT_QPA_PLATFORMTHEME'] = 'kde'
        env['QT_NO_XDG_DESKTOP_PORTAL'] = '1'
        env['PUNCHI_ICON_IMAGES'] = str(images)
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
            for stage, theme in enumerate(('owned-red', 'owned-green', 'owned-red', 'owned-green')):
                if stage:
                    globals_file.write_text(f'[Icons]\nTheme={theme}\n')
                    for group in range(6):
                        subprocess.run(['dbus-send', '--session', '--type=signal', '/KIconLoader',
                                        'org.kde.KIconLoader.iconChanged', f'int32:{group}'],
                                       env=env, check=True, timeout=3)
                deadline = time.monotonic() + 5
                matched = False
                last_pixels = []
                while time.monotonic() < deadline:
                    try:
                        line = lines.get(timeout=0.3)
                    except queue.Empty:
                        continue
                    if line is None:
                        raise AssertionError('Quickshell exited before the icon refresh finished.')
                    match = re.search(r'PUNCHI_ICON_FRAME (\d+)', line)
                    if not match:
                        continue
                    last_pixels = []
                    for index in range(6):
                        file = images / f'{match[1]}-{index}.png'
                        with Image.open(file) as image:
                            pixel = image.convert('RGB').getpixel((image.width // 2, image.height // 2))
                        last_pixels.append(pixel)
                        file.unlink()
                    if all(pixel == colors[theme] for pixel in last_pixels):
                        matched = True
                        print(f'Native icon theme stage {stage}: {theme}, all six production surfaces refreshed.')
                        break
                assert matched, f'Theme {theme} did not render; last icon pixels: {last_pixels}'
        except Exception:
            print("".join(output))
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join(timeout=2)
        unexpected = [line for line in output if re.search(r'\bWARN\b|\bERROR\b|PUNCHI_ICONS_FAILED', line)
                      and not re.search(r'\bWARN.*PUNCHI_ICON_FRAME \d+', line)]
        assert not unexpected, ''.join(unexpected)
        print('Native KDE notification: repeated same-name icon refresh, unchanged item state and clean runtime passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
