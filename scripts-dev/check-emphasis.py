#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the one-emphasis-band contract on every QML row that paints a band.

A row shows one emphasis band at a time. The pointer owns it while the pointer
moves; the keyboard owns it while the keyboard moves. A row cannot know that by
itself, so its owner publishes ``pointerEmphasis`` and every band binding has to
consult it through ``PopupRowHighlight``.

The checks are static: they catch the shape that produced the double hover, not
whether a specific pixel was painted.
"""

from pathlib import Path
import re
import sys

BAND = 'PopupRowHighlight'
OWNER = 'property bool pointerEmphasis'
BAND_GATE = re.compile(r'^\s*(hovered|focused|selected):\s*(.+)$')
INITIAL_FOCUS = re.compile(r'\bfunction (requestInitialFocus|tryInitialFocus)\b')


def band_blocks(text):
    """Yield (line, block) for each emphasis band declared in a QML file."""
    for match in re.finditer(rf'\b{BAND}\s*\{{', text):
        start = match.end()
        depth = 1
        index = start
        while index < len(text) and depth:
            if text[index] == '{':
                depth += 1
            elif text[index] == '}':
                depth -= 1
            index += 1
        line = text.count('\n', 0, match.start()) + 1
        yield line, text[start:index - 1]


def check_bands(relative, text, failures):
    for line, block in band_blocks(text):
        for offset, raw in enumerate(block.splitlines()):
            binding = BAND_GATE.match(raw)
            if binding is None:
                continue
            role, expression = binding[1], binding[2]
            if 'pointerEmphasis' not in expression:
                failures.append(
                    f'{relative}:{line + offset + 1}: "{role}" band ignores '
                    f'pointerEmphasis')


def check_owner(relative, text, failures):
    owns = BAND in text or re.search(r'pointerEmphasis\s*=', text) is not None
    if owns and OWNER not in text:
        failures.append(f'{relative}: writes pointerEmphasis without declaring '
                        f'"{OWNER}"')


def check_initial_focus(relative, text, failures):
    for match in INITIAL_FOCUS.finditer(text):
        body = text[match.end():]
        end = body.find('\n    function ')
        body = body if end < 0 else body[:end]
        if 'Qt.TabFocusReason' in body:
            line = text.count('\n', 0, match.start()) + 1
            failures.append(
                f'{relative}:{line}: initial focus hardcodes Qt.TabFocusReason; '
                f'the opening reason must be forwarded')


def main():
    root = Path(__file__).resolve().parents[1]
    failures = []
    checked = 0
    for directory in ('components', 'modules'):
        for path in sorted((root / directory).rglob('*.qml')):
            text = path.read_text()
            if BAND not in text and 'pointerEmphasis' not in text:
                continue
            relative = path.relative_to(root)
            checked += 1
            check_bands(relative, text, failures)
            check_owner(relative, text, failures)
            check_initial_focus(relative, text, failures)

    if failures:
        print('The one-emphasis-band contract is broken:', file=sys.stderr)
        for failure in failures:
            print(f'  {failure}', file=sys.stderr)
        return 1

    print(f'One emphasis band: {checked} QML files keep the contract.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
