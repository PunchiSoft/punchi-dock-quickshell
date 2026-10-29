# Dock

Dock.qml owns one Quickshell window per connected screen and its wiring.
PunchiDockServices.qml owns the models and services shared by every window, and
PunchiDockIpc.qml is the single command surface addressed by screen key. Screen and
virtual-desktop policy arrive as inputs, so a disallowed dock stays mapped
without reserving space or receiving input instead of closing the last window.
PunchiDockView.qml owns stable logical centers, intent signals, and horizontal surface
bounds. PunchiDockMagnification.qml owns the adapted cosine scale/displacement
functions and entry/exit progress.
