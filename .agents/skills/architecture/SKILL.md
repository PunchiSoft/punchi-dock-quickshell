---
name: architecture
description: Define modular Quickshell feature boundaries, services, shared QML components, and KDE adapter dependencies.
---

# Architecture

Identify behavior ownership, inputs, outputs, consumers, and side effects.
Keep root composition small, views declarative, providers independent of visuals,
and desktop integrations behind capability-aware adapters. Read
`docs/architecture.md`. Extract by responsibility around 300–400 lines, never by
quota. Do not create unused layers or catch-all managers. Document dependency
changes and preserve safe coexistence with Plasma.
