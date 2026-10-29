# Adapters

Desktop-specific implementations belong behind explicit capability contracts. A
service asks for a capability; an adapter proves it through a KDE or KWin API and
reports the result, including the unsupported case.

| Path | Boundary |
| --- | --- |
| `kde/` | KDE Frameworks, KWin and Plasma services for the dock |
| `kde/native/` | the C++ types registered into the `Punchi.Kde` QML module |
| `kde/protocols/` | Wayland protocol XML, scanned into headers at build time |
| `kde/window-state/` | the standalone `punchi-window-state` process and its models |

Rules:

- An adapter never draws. It exposes state and intents; a module or a component paints.
- Unsupported capabilities return a bounded failure the caller can render; they never
  simulate the native behavior in QML.
- Each native type lives in one domain folder under `kde/native/` and declares the group
  it belongs to: `appearance`, `applications`, `files`, `profile`, `updates` or `windows`.
