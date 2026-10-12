#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check portable documentation links and the repository skill catalog."""

from pathlib import Path
import re


def main():
    root = Path(__file__).resolve().parents[1]
    skills = list((root / '.agents/skills').glob('*/SKILL.md'))
    catalog = (root / '.agents/skills/README.md').read_text()
    for skill in skills:
        content = skill.read_text()
        frontmatter = re.match(r'^---\n(.*?)\n---\n', content, re.S)
        assert frontmatter, f'Missing frontmatter: {skill}'
        name = re.search(r'^name: (.+)$', frontmatter[1], re.M)
        description = re.search(r'^description: (.+)$', frontmatter[1], re.M)
        assert name and name[1] == skill.parent.name and description
        assert f'({skill.parent.name}/SKILL.md)' in catalog
    links = 0
    for path in [root / 'README.md', root / 'AGENTS.md', *sorted((root / 'docs').rglob('*.md')),
                 *sorted((root / '.agents').rglob('*.md'))]:
        content = path.read_text()
        assert all(line == line.rstrip() for line in content.splitlines()), path
        for match in re.findall(r'\[[^\]]*\]\(([^)]+)\)|src="([^"]+)"', content):
            target = next(value for value in match if value)
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
                continue
            resolved = (path.parent / target.split('#', 1)[0]).resolve()
            assert resolved.is_relative_to(root) and resolved.exists(), f'Broken link: {path}: {target}'
            links += 1
    print(f'Foundation: {len(skills)} skills and {links} local links passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
