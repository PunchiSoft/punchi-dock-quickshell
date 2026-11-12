#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the public changelog's section, category, version and link structure."""

from datetime import date
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
CHANGELOG = ROOT / 'CHANGELOG.md'
CATEGORIES = ('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')
LEGACY_BASELINE = (0, 1, 47)
VERSION_HEADING = re.compile(
    r'^## ((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)'
    r' — (\d{4}-\d{2}-\d{2})$')
PRIVATE_PATH = re.compile(r'(?:docs-private/|docs/records/|backup/|/home/[^\s)]+)')


def sections(lines):
    headings = [(index, line) for index, line in enumerate(lines)
                if line.startswith('## ')]
    return [(heading, lines[index + 1:(headings[n + 1][0]
                                        if n + 1 < len(headings) else len(lines))])
            for n, (index, heading) in enumerate(headings)]


def version_key(version):
    base, _, prerelease = version.partition('-')
    numeric = tuple(int(part) for part in base.split('.'))
    if not prerelease:
        return (numeric, 1, ())
    identifiers = tuple((0, int(part)) if part.isdigit() else (1, part)
                        for part in prerelease.split('.'))
    return (numeric, 0, identifiers)


def check_categories(body, section_name):
    category_heads = [(index, line[4:]) for index, line in enumerate(body)
                      if line.startswith('### ')]
    assert category_heads, f'{section_name} has no change categories'
    names = [name for _, name in category_heads]
    assert len(names) == len(set(names)), f'{section_name} repeats a category'
    assert all(name in CATEGORIES for name in names), \
        f'{section_name} has an unknown category'
    order = [CATEGORIES.index(name) for name in names]
    assert order == sorted(order), f'{section_name} categories are out of order'

    for n, (start, name) in enumerate(category_heads):
        end = category_heads[n + 1][0] if n + 1 < len(category_heads) else len(body)
        block = body[start + 1:end]
        item_count = 0
        in_item = False
        for line in block:
            if line.startswith('- '):
                assert line[2:].strip(), f'{section_name}/{name} contains an empty list item'
                item_count += 1
                in_item = True
            elif not line.strip():
                in_item = False
            elif line.startswith('  ') and in_item:
                continue  # Markdown source wrapping within the same list paragraph.
            else:
                raise AssertionError(
                    f'{section_name}/{name} contains text outside a list item: {line!r}')
        assert item_count, f'{section_name}/{name} is empty'


def main():
    text = CHANGELOG.read_text(encoding='utf-8')
    lines = text.splitlines()
    assert lines and lines[0] == '# Changelog', 'CHANGELOG.md must start with # Changelog'
    parsed = sections(lines)
    assert parsed and parsed[0][0] == '## Unreleased', 'Unreleased must be the first section'
    assert sum(heading == '## Unreleased' for heading, _ in parsed) == 1, \
        'CHANGELOG.md must contain exactly one Unreleased section'

    keys = []
    for heading, body in parsed:
        if heading == '## Unreleased':
            if any(line.strip() for line in body):
                check_categories(body, 'Unreleased')
            continue
        match = VERSION_HEADING.fullmatch(heading)
        assert match, f'Invalid or unsupported release heading: {heading}'
        version = tuple(int(part) for part in match[1].split('-', 1)[0].split('.'))
        try:
            parsed_date = date.fromisoformat(match[2])
        except ValueError as error:
            raise AssertionError(f'Invalid release date in {heading}') from error
        assert parsed_date.isoformat() == match[2], f'Release date is not ISO format: {heading}'
        keys.append(version_key(match[1]))
        # This untagged snapshot predates the release-oriented category layout.
        if version != LEGACY_BASELINE:
            check_categories(body, heading)
        assert any(line.startswith('- ') for line in body), \
            f'Release section has no change entries: {heading}'
    assert keys == sorted(set(keys), reverse=True), \
        'Dated release headings must be unique and newest-first by SemVer'

    assert not PRIVATE_PATH.search(text), 'CHANGELOG.md links to or names a local/private path'
    print(f'Changelog: {len(parsed) - 1} dated sections and a valid Unreleased section.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
