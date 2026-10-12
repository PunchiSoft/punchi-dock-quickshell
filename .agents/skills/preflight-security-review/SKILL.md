---
name: preflight-security-review
description: Review authorized scope, untrusted inputs, side effects, secrets, and public artifacts before modifying or publishing the standalone desktop shell.
---

# Security preflight

Inspect affected inputs, consumers, files, and Git state when available before
editing. Keep this review scoped to the intended change.

- Check shell construction, paths, URLs, desktop metadata, JSON limits, and FFI.
- Use argument-based launch APIs and explicit failure handling.
- Keep secrets, personal paths, diagnostics, SDK trees, and binaries out of Git.
- Public docs are tracked; private engineering evidence belongs in ignored notes.
- Do not add telemetry or unrelated privileges, network calls, or system changes.
- Reused files preserve license notices and exclude private source-project history.

Before publication, inspect the exact staged diff and actual package contents.
GitHub-ready files do not authorize push or release. Resolve concrete risks before
proceeding; do not invent hypothetical approval gates for ordinary local edits.
