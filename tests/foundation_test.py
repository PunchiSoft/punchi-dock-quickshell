#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check portable documentation links, the skill catalog, and skill budgets."""

from pathlib import Path
import re

NAME_PATTERN = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
DESCRIPTION_LIMIT = 300
SKILL_LINE_LIMIT = 500
CATALOG_ROW = re.compile(r'^\| \[([a-z0-9-]+)\]\(([a-z0-9-]+)/SKILL\.md\)', re.M)
REFERENCE_TARGET = re.compile(r'(\.\./)?references/[\w./-]+\.md')


def check_skill(skill, catalog):
    content = skill.read_text()
    frontmatter = re.match(r'^---\n(.*?)\n---\n', content, re.S)
    assert frontmatter, f'Missing frontmatter: {skill}'
    name = re.search(r'^name: (.+)$', frontmatter[1], re.M)
    description = re.search(r'^description: (.+)$', frontmatter[1], re.M)
    assert name and name[1] == skill.parent.name and description
    directory = skill.parent.name
    assert NAME_PATTERN.fullmatch(directory) and len(directory) <= 64, f'Invalid skill name: {directory}'
    assert len(description[1]) <= DESCRIPTION_LIMIT, f'Description over budget: {skill}'
    assert 'Use when' in description[1], f'Description lacks a "Use when" clause: {skill}'
    body = content[frontmatter.end():]
    assert len(body.splitlines()) <= SKILL_LINE_LIMIT, f'Skill body over budget: {skill}'
    assert body.lstrip('\n').startswith('# '), f'Skill body must start with a level-1 title: {skill}'
    for target in re.findall(r'\]\(([^)]+)\)', content):
        if 'references/' in target:
            assert REFERENCE_TARGET.fullmatch(target), \
                f'Reference must be one level deep or shared: {skill}: {target}'
    assert f'({directory}/SKILL.md)' in catalog, f'Missing catalog entry: {directory}'


def main():
    root = Path(__file__).resolve().parents[1]
    skills = sorted((root / '.agents/skills').glob('*/SKILL.md'))
    catalog = (root / '.agents/skills/README.md').read_text()
    for skill in skills:
        check_skill(skill, catalog)
    catalogued = [entry[0] for entry in CATALOG_ROW.findall(catalog)]
    assert catalogued == sorted(catalogued), 'Skill catalog is not in alphabetical order'
    assert catalogued == [skill.parent.name for skill in skills], \
        'Skill catalog does not match the skill directories'
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
    print(f'Foundation: {len(skills)} skills, trigger clauses, budgets and {links} local links passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
