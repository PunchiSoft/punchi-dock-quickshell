# Skill trigger evals

A skill only helps when it activates. The `description` field carries the whole
triggering decision, so it is measured rather than assumed.

This is a manual procedure with a fixed query set. It is not wired into CTest:
activation depends on the agent client, its model, and the session, so a
deterministic assertion would be a false guarantee.

## Procedure

1. Start a fresh chat in the repository with the skill set enabled.
2. Send one query verbatim, without extra context.
3. Record whether the expected skill was loaded. In VS Code, the session log and
   the Agent Customizations editor show which skills were consulted.
4. Repeat each query three times; model behavior is not deterministic.
5. Compute the trigger rate per query.
6. A should-trigger query passes above 0.5; a should-not-trigger query passes
   below 0.5.
7. After editing a description, re-run only the queries that name that skill,
   plus every near-miss that shares its vocabulary.

## Query set

Should trigger:

| # | Query | Expected skill | Why it is not obvious |
|---|---|---|---|
| 1 | "revisá el diff antes de que lo commitee" | `code-review` | the user never says "review" or "skill"; the intent is a pre-commit check |
| 2 | "¿esto está listo? quiero abrir el PR" | `verification-before-completion` | asks about readiness, not about evidence levels |
| 3 | "antes de tocar nada, qué entra y qué no" | `requirements-capture` | scope question with no feature named |
| 4 | "agregué una skill y nunca se activa" | `skill-authoring` | describes the symptom, not the fix |
| 5 | "the dock stutters when I move the pointer fast" | `animations` | symptom, not the word "animation" |
| 6 | "el switch de auto-ocultar no hace nada" | `control-connection-review` | a broken control, no mention of tracing |
| 7 | "¿podemos usar la campana nativa de KWin?" | `kde-integration` | asks about a native mechanism without naming the framework |
| 8 | "este texto nuevo de aviso, ¿lo apruebo?" | `notice-copy-approval` | approval question, not a copy request |
| 9 | "borrá el popup viejo y sus restos" | `safe-removal-review` | imperative deletion with implicit consumer checks |
| 10 | "the popup row and the selected row look the same" | `selection-emphasis` | visual complaint, not a state-model term |
| 11 | "voy a empezar esto, armame la rama" | `branch-baseline` | asks for a branch, never mentions `main` or the base |

Should not trigger, near misses:

| # | Query | Must not trigger | Why it is a near miss |
|---|---|---|---|
| 12 | "explain how Qt Quick bindings work" | `code-review` | reviews vocabulary, general knowledge request |
| 13 | "add a comment to the PR on GitHub" | `verification-before-completion` | "PR" appears, but the task is a GitHub action |
| 14 | "rename `theme` to `palette` across the repo" | `requirements-capture` | mechanical refactor already scoped |
| 15 | "what does agentskills.io say about allowed-tools?" | `skill-authoring` | external documentation lookup |
| 16 | "why does Plasma restart my panel after login?" | `kde-integration` | Plasma topic, but a user-environment question |
| 17 | "increase the popup width by 20 px" | `selection-emphasis` | popup geometry, not selection emphasis |
| 18 | "translate the README to English" | `localization` | documentation language, not runtime catalogs |
| 19 | "delete build/ and rebuild" | `safe-removal-review` | generated output, no consumer graph |
| 20 | "summarize what changed in 0.1.45" | `code-review` | changelog reading, no diff review |
| 21 | "does this animation look good to you?" | `motion-review` | aesthetic opinion, no audit requested |
| 22 | "mergeá esta rama en main" | `branch-baseline` | `main` appears, but the task is a merge request |

## Recording

Keep the run record in the local `docs/records/audits/` note for the change. Record the
client, model, date, per-query score, and the description that changed. A
trigger rate below threshold is evidence about the description, not about the
query.
