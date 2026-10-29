#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""List or delete record evidence that no record cites and that has aged out.

The rule lives in `docs/records/assets/README.md`: evidence a record cites is kept
for as long as the record exists, and temporary captures nobody cites are removed
after a retention window. This script enforces that window without ever touching a
cited path.

A file counts as cited when a Markdown file under `docs/` names it, names one of the
directories that contain it, or links it with a relative path.

The default run only reports. Deletion needs `--apply`.
"""

from pathlib import Path
import argparse
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'
RECORDS = DOCS / 'records'
ASSETS = RECORDS / 'assets'
DEFAULT_DAYS = 7


def markdown_text() -> str:
    return '\n'.join(path.read_text(encoding='utf-8', errors='replace')
                     for path in DOCS.rglob('*.md'))


def has_record(folder: str) -> bool:
    """A folder named after a record belongs to it, so its files are cited."""
    return any((RECORDS / kind / f'{folder}.md').is_file()
               for kind in ('changes', 'reviews', 'releases'))


def citation_keys(path: Path) -> list[str]:
    """Names a record can use to cite this file: its path, record and capture set.

    A record cites its own folder, a shared capture set, or an exact path; the
    generic `changes`/`reviews` level is never enough on its own.
    """
    keys = [path.relative_to(DOCS).as_posix()]
    parts = path.relative_to(ASSETS).parts
    if len(parts) >= 3:
        keys.append(parts[1])
    if len(parts) >= 4:
        keys.append(parts[2])
    return keys


def is_cited(path: Path, text: str) -> bool:
    parts = path.relative_to(ASSETS).parts
    if len(parts) >= 2 and has_record(parts[1]):
        return True
    return any(key in text for key in citation_keys(path))


def evidence_files() -> list[Path]:
    if not ASSETS.is_dir():
        return []
    return sorted(path for path in ASSETS.rglob('*')
                  if path.is_file() and path.name != 'README.md')


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Remove uncited record evidence older than the retention window.')
    parser.add_argument('--days', type=int, default=DEFAULT_DAYS,
                        help=f'retention window in days (default {DEFAULT_DAYS})')
    parser.add_argument('--apply', action='store_true',
                        help='delete the reported files; the default only reports')
    parser.add_argument('--dry-run', action='store_true',
                        help='report only; this is already the default')
    arguments = parser.parse_args()
    if arguments.days < 0:
        parser.error('--days must not be negative')
    if arguments.apply and arguments.dry_run:
        parser.error('--apply and --dry-run are mutually exclusive')

    text = markdown_text()
    cutoff = time.time() - arguments.days * 86400
    stale = []
    cited = 0
    young = 0
    for path in evidence_files():
        if is_cited(path, text):
            cited += 1
            continue
        if path.stat().st_mtime > cutoff:
            young += 1
            continue
        stale.append(path)

    total = len(stale)
    size = sum(path.stat().st_size for path in stale)
    verb = 'Deleting' if arguments.apply else 'Would delete'
    for path in stale:
        print(f'{verb}: {path.relative_to(ROOT)}')
    if arguments.apply:
        for path in stale:
            path.unlink()
        for directory in sorted(ASSETS.rglob('*'), key=lambda item: len(item.parts),
                                reverse=True):
            if directory.is_dir() and not any(directory.iterdir()):
                directory.rmdir()

    print(f'{total} uncited files older than {arguments.days} days '
          f'({size / 1024:.0f} KiB); {cited} cited, {young} still inside the window')
    if total and not arguments.apply:
        print('Re-run with --apply to delete them.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
