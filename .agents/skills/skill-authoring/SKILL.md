---
name: skill-authoring
description: Create, revise, and validate repository skills so they trigger on the right requests and stay within the context budget. Use when adding a skill, fixing a skill that never activates, or auditing the catalog in .agents/skills.
license: GPL-3.0-or-later
---

# Skill authoring

A skill is a context investment: name and description are always loaded, the body
loads on activation, references load on demand. Write for the smallest budget that
still changes behavior.

## Procedure

1. Extract the workflow from a real task: the steps that worked, the corrections
   you made, the formats that were used. Do not ask a model to invent a domain.
2. Decide the unit. One coherent responsibility that composes with the existing
   skills; check `.agents/skills/README.md` first for the current owner.
3. Write the description as what plus when, in imperative voice, using the words
   a user would type, and include a `Use when` clause.
4. Write the body as a procedure with a validation block. Leave out declarations
   that `AGENTS.md` already states.
5. Put stable detail in `references/` and name the condition that makes it
   necessary. Material shared by several skills lives in
   `.agents/skills/references/`.
6. Add the skill to the catalog, then run the foundation test.
7. Compare behavior with and without the skill on one real prompt. If nothing
   changes, delete the skill or move the rule into `AGENTS.md`.

## Structure

```text
.agents/skills/<name>/SKILL.md      required
.agents/skills/<name>/references/   detail loaded on demand
.agents/skills/references/          material shared by several skills
```

## Budget

- Description: under 300 characters, one sentence of what and one of when.
- Body: under 500 lines, ideally under 150, procedure first.
- References: one level inside the skill or in the shared folder.
- Bundle a script only when the same logic is rebuilt on every run; a command
  copied from `docs/development.md` stays a command.

## Gotchas

- A description that only summarizes a topic does not trigger; the agent matches
  the situation, not the subject.
- The body loads in full on activation, so repeating `AGENTS.md` spends context
  without changing behavior.
- Two skills claiming one trigger produce contradictory instructions. Pick an
  owner and cross-reference it under `## Coordination`.
- `name` must equal the directory name in lowercase kebab-case; an invalid name
  fails silently in the editor.
- `tests/foundation_test.py` checks structure, never quality. Passing it is not
  evidence that a skill works.
- A skill teaching a fragile sequence must be prescriptive; one teaching judgment
  must give defaults, not menus.
- An adapted skill keeps its origin in `NOTICE.md` and its `metadata.source`.

## Validation

```bash
python3 tests/foundation_test.py
```

For activation, use the query set described in `tests/skills-trigger-evals.md`.
Report the trigger phrases chosen, the real prompt used for comparison, and what
the agent did differently without the skill.
