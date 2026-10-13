#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Create owned KDE metadata with differing window/executable/desktop IDs."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    applications = Path(os.environ['XDG_DATA_HOME']) / 'applications'
    applications.mkdir()
    fixtures = [
        ('punchi-owned-workstation', 'Owned Workstation', '/owned/bin/punchi-owned-vmware %U', 'punchi-owned-wmclass'),
        ('punchi-owned-alternative', 'Owned Alternative', '/owned/bin/owned-shared-runner', ''),
        ('punchi-owned-duplicate', 'owned-duplicate-name', '/other/bin/owned-shared-runner', ''),
        ('punchi-owned-duplicate-name', 'owned-duplicate-name', '/other/bin/different-owned-runner', ''),
        ('punchi-owned-wrapper', 'Owned Wrapper', 'env OWNED=1 /owned/bin/wrapped-app', ''),
    ]
    created = []
    try:
        for id, name, exec, wmclass in fixtures:
            path = applications / (id + '.desktop')
            path.write_text('[Desktop Entry]\nType=Application\n'
                            f'Name={name}\nExec={exec}\nStartupWMClass={wmclass}\n')
            created.append(path)
        indexer = shutil.which('kbuildsycoca6')
        assert indexer
        subprocess.run([indexer, '--noincremental'], check=True, capture_output=True, text=True, timeout=10)
        return subprocess.run([sys.argv[1]], timeout=20).returncode
    finally:
        for path in created:
            path.unlink()


if __name__ == '__main__':
    raise SystemExit(main())
