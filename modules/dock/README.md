# Dock

Dock.qml owns one Quickshell window per connected screen and its wiring.
DockServices.qml owns the models and services shared by every window, and
DockIpc.qml is the single command surface addressed by screen key. Screen and
virtual-desktop policy arrive as inputs, so a disallowed dock stays mapped
without reserving space or receiving input instead of closing the last window.
DockView.qml owns stable logical centers, intent signals, and horizontal surface
bounds. DockMagnification.qml owns the adapted cosine scale/displacement
functions and entry/exit progress.
