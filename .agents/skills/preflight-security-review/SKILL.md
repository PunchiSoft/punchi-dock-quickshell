---
name: preflight-security-review
description: Review authorized scope, untrusted inputs, side effects, secrets, and public artifacts before modifying or publishing the standalone desktop shell. Use when a change reads external data, launches a process, writes user state, or precedes a push or publication.
license: GPL-3.0-or-later
---

# Security preflight

Review the change before it exists: what it reads, what it writes, what it
launches, and what it would publish.

## Procedure

1. State the authorized scope in one sentence, including files and operations.
2. List every untrusted input the change touches: desktop entries, paths, file
   names, URLs, JSON, D-Bus replies, package metadata, clipboard text.
3. For each input, bound it: length, count, recursion, time, and the behaviour on
   malformed or missing data.
4. List side effects: process launch, file write, settings write, network,
   privileged call, and the failure path of each.
5. Check secrets and personal data in the diff, in fixtures, and in logs.
6. Decide what becomes public if this is pushed.
7. Reject or defer with a named risk; do not invent approval gates for ordinary
   local edits.

## Rules

- Check shell construction, paths, URLs, desktop metadata, JSON limits, and FFI.
- Use argument-based launch APIs and explicit failure handling.
- Keep secrets, personal paths, diagnostics, SDK trees, and binaries out of Git.
- Public docs are tracked; private engineering evidence belongs in ignored notes.
- Do not add telemetry or unrelated privileges, network calls, or system changes.
- Reused files preserve license notices and exclude private source-project history.

Before publication, inspect the exact staged diff and actual package contents.
GitHub-ready files do not authorize push or release.

## Gotchas

- A desktop entry `Exec` value is untrusted data, not a command line: parse
  tokens and launch with an argument list, never through a shell.
- File names from a folder listing reach QML as data. A name containing `://`
  or `..` must not become a path or a URL.
- Models can emit rows with empty or non-UTF8 fields; a binding that assumes a
  string breaks the surface, not the model.
- A `Process` element with a concatenated command string reintroduces the shell
  parsing the native launcher avoided.
- Fixtures that record real user paths or documents leak through the repository
  even when the runtime code is clean.

## Validation

```bash
git --no-pager diff --cached --stat
git --no-pager diff --cached | rg -n 'Process|exec|http[s]?://|/home/'
```

Report each checked category and the residual risk you accepted.
