#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Resolve the build tree the user setup writes for this distribution.

The shell keeps the single source of truth in `scripts-user/lib/build-dir.sh`,
so the developer scripts and the tests ask it instead of repeating the rule.
"""

from pathlib import Path
import shlex
import subprocess


def resolve_build_dir(root: Path) -> Path:
    """Return the tree holding artifacts: `build-<distro>`, else legacy `build/`."""
    library = root / 'scripts-user/lib/build-dir.sh'
    script = (f'punchi_project_root={shlex.quote(str(root))}; '
              f'source {shlex.quote(str(library))}; '
              'punchi_build_dir_existing || punchi_build_dir')
    result = subprocess.run(['bash', '-c', script], capture_output=True,
                            text=True, check=False)
    resolved = result.stdout.strip()
    return Path(resolved) if resolved else root / 'build'
