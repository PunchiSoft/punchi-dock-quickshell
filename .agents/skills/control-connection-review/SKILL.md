---
name: control-connection-review
description: Trace QML interaction and settings through the services and KDE adapters to an observable effect and reactive UI update. Use when a control appears wired but does nothing, a setting does not persist, or a claim of working behavior needs proof.
license: GPL-3.0-or-later
---

# Intent-to-effect tracing

A control works only when the whole chain is connected and reactive, not when the
code reads correctly.

## Procedure

1. Define the input, expected effect, active consumer, timing, units, and
   conditions.
2. Trace control signal to service to KDE adapter or provider, then state
   notification to rendered or system result.
3. Open each link and name the property or signal that carries the value.
4. Exercise the initiating control. Never assign the final property directly.
5. Change the source again and confirm the result follows; confirm a neighbouring
   independent setting is unaffected.
6. Classify the chain and record the precise broken link.

## Worked trace

The dock context menu's auto-hide action:

1. `modules/dock/DockContextContent.qml:326` emits `autoHideRequested`.
2. `modules/dock/DockContextPopup.qml:172` dismisses the popup and re-emits it.
3. `modules/dock/Dock.qml:357` toggles `settings.panelMode` between `autohide`
   and `overlay`.
4. `DockPanelPolicy` (`modules/dock/Dock.qml:147`) recomputes `effectiveMode`.
5. `modules/dock/Dock.qml:99` rebinds `autoHide`, so
   `DockVisibilityController.shouldHide` changes.
6. The surface reads `boundedSlideProgress` and hides.

A break at step 1 is a missing signal connection, at step 3 a missing write, at
step 5 a stale copy. Each is a different defect with a different fix.

## Rules

Confirm that the chain uses the native KDE provider before accepting a custom
substitute. A QML imitation, shell command or successful window does not prove
that KDE behavior is followed. If a native path is unavailable, classify the
fallback as intentional and record the version/capability gap and evidence limits.

Classify a chain as verified, statically connected, partial, disconnected,
nonreactive, intentional exception, or insufficient evidence. Finding references
or saving a value alone does not establish behavior.

Check live windows, reopening, independent neighboring settings, and consumers of
shared helpers. A pure helper test cannot prove end-to-end application behavior.
Do not invent a global audit or remove a working control because its utility is
debatable.

## Gotchas

- A `Binding` on a property that the same component also assigns stops silently
  and keeps the last assigned value.
- A value read once into a local variable stops reacting; read it inside the
  expression that uses it.
- Two consumers of one service can disagree when one caches a copy. Compare the
  service value, not the caches.
- A saved value proves persistence, not application. Reopening the surface and
  starting a fresh process are separate checks.
- Setting a property from a test proves the consumer, not the control: the defect
  is often a missing handler behind the control.
- A successful reload in `qs log` means the QML loaded, not that the chain ran.

## Validation

```bash
ctest --test-dir build -R '^adapter_contract$' --output-on-failure
qs log --path ~/.local/share/punchi-dock-quickshell -t 40
```

Report the classification, the exact broken link with `file:line`, and which
checks were executed rather than read.
