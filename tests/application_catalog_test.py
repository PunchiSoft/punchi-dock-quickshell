#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Own an editor, a browser and the session default, then run the catalogue test."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
    applications.mkdir(parents=True)
    entries = [
        ('punchi-catalog-browser', 'Owned Catalog Browser', 'punchi-catalog-browser',
         'x-scheme-handler/https;x-scheme-handler/http;text/html;'),
        ('punchi-catalog-editor', 'Owned Catalog Editor', 'accessories-text-editor', 'text/plain;'),
    ]
    created = []
    try:
        for storage_id, name, icon, mime_types in entries:
            path = applications / (storage_id + '.desktop')
            path.write_text('[Desktop Entry]\nType=Application\n'
                            f'Name={name}\nExec=/bin/true %U\nIcon={icon}\n'
                            f'MimeType={mime_types}\nCategories=Network;WebBrowser;\n')
            created.append(path)
        config = Path(os.environ['XDG_CONFIG_HOME'])
        config.mkdir(parents=True, exist_ok=True)
        (config / 'mimeapps.list').write_text(
            '[Default Applications]\nx-scheme-handler/https=punchi-catalog-browser.desktop\n')
        indexer = shutil.which('kbuildsycoca6')
        assert indexer, 'The KDE application cache builder is required for this owned fixture'
        subprocess.run([indexer, '--noincremental'], check=True, capture_output=True, text=True, timeout=10)
        return subprocess.run([sys.argv[1]], timeout=20).returncode
    finally:
        for path in created:
            path.unlink()


if __name__ == '__main__':
    raise SystemExit(main())
