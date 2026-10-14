#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise actual folder models and popup controls with owned Downloads data."""
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import time
import shutil
import json


def main():
    root = Path(__file__).resolve().parents[1]
    capture = '--capture' in sys.argv[2:]
    evidence = Path(tempfile.mkdtemp(prefix='downloads-preview-', dir=root / 'notes/changes')) if capture else None
    with tempfile.TemporaryDirectory(prefix='punchi-folders-') as temporary:
        owned = Path(temporary)
        downloads = owned / 'Owned Downloads'
        downloads.mkdir()
        nested = downloads / 'nested'
        nested.mkdir()
        (nested / 'inside.txt').write_text('Owned inner file.\n')
        (downloads / 'old.txt').write_text('Owned old file.\n')
        (downloads / 'newest.txt').write_text('Owned recent file.\n')
        (downloads / 'A deliberately long folder popup filename for marquee.txt').write_text('Owned long name.\n')
        (downloads / '.hidden').write_text('Owned hidden file.\n')
        now = time.time()
        os.utime(nested, (now - 120, now - 120))
        os.utime(downloads / 'old.txt', (now - 240, now - 240))
        env = os.environ.copy()
        config = owned / 'config'
        config.mkdir()
        (config / 'user-dirs.dirs').write_text(f'XDG_DOWNLOAD_DIR="{downloads}"\n')
        env.update(XDG_CONFIG_HOME=str(config), QT_NO_XDG_DESKTOP_PORTAL='1')
        input_path = root / 'tests/folders'
        if capture:
            preview = owned / 'preview'
            for name in ('modules', 'services', 'components', 'adapters', 'config'):
                shutil.copytree(root / name, preview / name)
            input_path = preview / 'tests/folders'
            shutil.copytree(root / 'tests/folders', input_path)
            fixture = input_path / 'tst_folder_container.qml'
            source = fixture.read_text()
            # Native KDE style and palettes belong exclusively to this fixture.
            env.pop('QT_QUICK_CONTROLS_STYLE', None)
            for palette, background, foreground in [('light', '#f6f6f6', '#222222'), ('dark', '#242424', '#eeeeee')]:
                target = evidence / palette
                target.mkdir()
                (config / 'kdeglobals').write_text(f'[Colors:Window]\nBackgroundNormal={background}\nForegroundNormal={foreground}\n')
                fixture.write_text(source.replace('property string captureDirectory: ""',
                    'property string captureDirectory: ' + json.dumps(str(target))))
                result = subprocess.run([sys.argv[1], '-input', str(input_path)], env=env, timeout=25)
                if result.returncode: return result.returncode
            print(f'Owned preview evidence: {evidence}')
            return 0
        return subprocess.run([sys.argv[1], '-input', str(input_path)], env=env, timeout=25).returncode


if __name__ == '__main__':
    raise SystemExit(main())
