# Skill catalog

All skills supplement [AGENTS.md](../../AGENTS.md). Adapted workflows originate
from Punchi Dock Rust; the movement, audit, cost, and material skills come from
the Punchi Dock Remastered motion pack, adapted to Quickshell and KDE Plasma/KWin;
Quickshell-specific workflows are new.

| Skill | Purpose | Use when | Depends on |
|---|---|---|---|
| [accessibility](accessibility/SKILL.md) | Keyboard path, names, focus continuity, scaling | an interactive surface or an accessibility claim is added or reviewed | `qml-ui-creation` |
| [animation-performance](animation-performance/SKILL.md) | Per-frame cost, cost classes, delegate and effect limits | a visual change may affect frame cost | `fluid-motion` |
| [animations](animations/SKILL.md) | Motion policy, classification, durations, easing | a transition is added or judged | `fluid-motion`, `animation-performance` |
| [architecture](architecture/SKILL.md) | Ownership, boundaries, dependency direction | a service, module, primitive or adapter is added | `kde-integration` |
| [branch-baseline](branch-baseline/SKILL.md) | Branch base verification and the justified sub-branch | a change starts, a branch is created or switched, or the current base is in doubt | `modification-cycle` |
| [code-review](code-review/SKILL.md) | Diff review with blocking and non-blocking findings | a change is about to be committed or opened | `control-connection-review`, `testing` |
| [commit-push-versioning](commit-push-versioning/SKILL.md) | Delivery version, staged content, hand-off | the user asks to commit or push | `code-review`, `pr-delivery` |
| [control-connection-review](control-connection-review/SKILL.md) | Intent-to-effect tracing through services and adapters | a control looks wired but has no effect | `kde-integration` |
| [documentation](documentation/SKILL.md) | Public README, changelog, local record, attribution | public documentation or a support claim changes | - |
| [fluid-motion](fluid-motion/SKILL.md) | Qt Quick mechanism, continuity, reversibility | one concrete animation is written or corrected | `accessibility` |
| [kde-integration](kde-integration/SKILL.md) | Native-first KDE and KWin behavior | a change touches KWin, Plasma or KDE Frameworks | `qt-kde-reference` |
| [localization](localization/SKILL.md) | `qsTr` source strings and catalog verification | a runtime string or a language claim changes | `notice-copy-approval` |
| [modification-cycle](modification-cycle/SKILL.md) | Staged feature delivery on a branch from `main` | a feature or multi-commit change starts | `requirements-capture`, `documentation` |
| [motion-design](motion-design/SKILL.md) | Interaction policy and animation resolved together | input behaviour and motion must be fixed together | `animations`, `fluid-motion` |
| [motion-review](motion-review/SKILL.md) | Read-only motion audit with the MOTION catalog | existing motion is reviewed | `animations` |
| [notice-copy-approval](notice-copy-approval/SKILL.md) | Wording and emphasis approval before copy ships | a notice, tooltip or help text would reach the user | - |
| [pr-delivery](pr-delivery/SKILL.md) | Pull request body, validation evidence, close | the user asks to open, update or check a pull request | `code-review`, `verification-before-completion` |
| [preflight-security-review](preflight-security-review/SKILL.md) | Untrusted input, side effects, secrets, publication | a change reads external data, launches or publishes | `safe-removal-review` |
| [publication-review](publication-review/SKILL.md) | Repository content, history and settings audit | visibility changes or a public mirror is created | `preflight-security-review` |
| [qml-ui-creation](qml-ui-creation/SKILL.md) | Modular windows, Qt-only views, native styling | a window, panel, popup or control is added | `accessibility`, `selection-emphasis` |
| [qt-kde-reference](qt-kde-reference/SKILL.md) | API and version evidence for Qt, KDE and Quickshell | a symbol is new, unfamiliar or version-sensitive | - |
| [quickshell-development](quickshell-development/SKILL.md) | Quickshell modules, editor setup, reload lifecycle | Quickshell-specific QML is written or diagnosed | `qt-kde-reference` |
| [requirements-capture](requirements-capture/SKILL.md) | Scope, acceptance criteria, out-of-scope, risks | a request is ambiguous or a change starts | - |
| [review-cycle](review-cycle/SKILL.md) | Regression diagnosis with confirmed findings | a behavior that used to work fails | `control-connection-review`, `testing` |
| [safe-removal-review](safe-removal-review/SKILL.md) | Deletion, overwrite, batch moves, retirement | material would be deleted, moved or rewritten | - |
| [selection-emphasis](selection-emphasis/SKILL.md) | One primary emphasis for selection and hover | a list, grid, tab or sidebar shows a current item | `accessibility` |
| [skill-authoring](skill-authoring/SKILL.md) | Create, revise and validate skills | a skill is added or never activates | `documentation` |
| [surface-effects](surface-effects/SKILL.md) | Material and finish levels, lowest cost first | a surface needs depth, glass, blur or a shader | `animation-performance` |
| [testing](testing/SKILL.md) | Test selection, isolation, real-session evidence | a test is added, a bug is reproduced, evidence is chosen | - |
| [verification-before-completion](verification-before-completion/SKILL.md) | Evidence sufficiency before claiming done | a task looks complete | `testing` |

## Shared references

- [Motion doctrine](references/motion-doctrine.md): the movement rules shared by
  `fluid-motion`, `animations`, `animation-performance` and `surface-effects`.
  Skills link it as `../references/motion-doctrine.md`; it has no owning skill so
  that no skill depends on another skill's directory.

## Reuse and attribution

These skills are published with the project under `GPL-3.0-or-later`; the full
text is in [LICENSE](../../LICENSE). They began as original work for this project,
and the ones that adapt material from another project say so in their
`metadata.source`. You may copy, adapt and redistribute them, including inside
another agent, provided you keep:

- the `license` field of each `SKILL.md` frontmatter,
- the copyright and license notices of this repository,
- every `metadata.source` entry, which records the project an adapted skill came
  from.

The license already requires those notices, so nothing here adds a condition to
it. Citing this repository and the commit you took the skills from is appreciated
but is a courtesy, not a requirement. If you redistribute a modified catalog,
point the attribution at this repository instead of presenting the work as
original. `project_foundation` checks that this section and the `license` fields
stay in place.

## Conventions

- `description` states what the skill does and when it applies, in imperative
  voice, and includes a `Use when` clause.
- Body under 500 lines, procedure first, then gotchas, then validation.
- Human-readable detail goes to `references/`; executable policy stays in the
  body.
- Every entry appears here and is verified by `tests/foundation_test.py`.
- Activation is measured with the query set in
  [trigger evals](../../tests/skills-trigger-evals.md), never assumed.
