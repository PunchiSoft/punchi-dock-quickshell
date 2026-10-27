---
name: localization
description: Prepare English UI source strings and verify standalone Qt or KI18n translation setup, extraction, catalogs, and packaging. Use when adding or changing a runtime string, a translation catalog, or a language claim.
license: GPL-3.0-or-later
---

# Quickshell localization

Before the first runtime string, inspect or establish the actual translation
mechanism. Quickshell is not a Plasma applet: plain QML cannot assume the
injected `i18n` functions exist, and only the English fallback is supported
today.

## Procedure

1. Find the string in its surface and confirm it is user-visible runtime copy.
2. Wrap it with `qsTr` and a stable context, or `qsTranslate` when the context
   must be explicit.
3. Use named placeholders and plural forms instead of concatenating fragments.
4. Check that the surface still lays out with longer translations.
5. If a catalog exists, rebuild it and review every supported language.
6. Verify that the Quickshell configuration loads the catalog before claiming
   language support.

## Rules

- Use English source, stable context, placeholders, and plural support.
- Keep translations in catalogs and preserve reactive language updates where
  supported. Do not translate domain state prematurely.
- Include accessibility, tooltips, errors, and empty states in extraction.
- Run the tools of the chosen mechanism and review all supported catalogs.
- Verify loading and packaging in the Quickshell configuration; do not reuse
  KPackage locale paths or absent translation scripts.

Get explanatory-copy approval first when applicable. Never claim language
support with incomplete catalogs or confuse English engineering docs with UI text.

## Gotchas

- No catalog exists in this repository: 285 `qsTr` calls across 30 QML files
  fall back to English. Adding a language starts with choosing catalog loading
  and packaging, not with adding more `qsTr` calls.
- `i18n()` and `i18nc()` belong to the Plasma applet runtime. They are undefined
  in Quickshell and fail when the file loads, not when the string is shown.
- A view created behind a `Loader` keeps the language it was created with
  unless the binding is refreshed. Changing language is not a reload.
- Concatenating a translated fragment with a unit or separator cannot be
  reordered by a translator. Use one complete string with a placeholder.
- Translating `Accessible.name` separately from the visible label makes the two
  disagree for screen readers.

## Validation

```bash
rg -n 'qsTr|qsTranslate|i18n\(' --glob '*.qml' -g '!build/**'
ctest --test-dir build --output-on-failure -R 'qml_lint|dock_components'
```

State the mechanism, the catalogs reviewed, and whether loading was verified in
a running Quickshell instance.
