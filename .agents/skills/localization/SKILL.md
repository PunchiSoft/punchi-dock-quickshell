---
name: localization
description: Prepare English UI source strings and verify standalone Qt or KI18n translation initialization, extraction, catalogs, and packaging.
---

# Quickshell localization

Before the first runtime strings, inspect or establish the actual translation
mechanism. Choose Qt translation or initialized KI18n deliberately; plain QML
cannot assume the applet's injected `i18n` functions exist.

- Use English source, stable context, placeholders, and plural support.
- Keep translations in catalogs and preserve reactive language updates where
  supported. Do not translate domain state prematurely.
- Include accessibility, tooltips, errors, and empty states in extraction.
- Run the tools of the chosen mechanism and review all supported catalogs.
- Verify loading and packaging in the Quickshell configuration; do not reuse
  KPackage locale paths or absent translation scripts.

Get explanatory-copy approval first when applicable. Never claim language
support with incomplete catalogs or confuse English engineering docs with UI text.
