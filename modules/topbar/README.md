# Top bar

The optional top panel. `PunchiTopBar` is the Quickshell host for one screen: a
`PanelWindow` anchored to the top edge that reserves the bar height and keeps a
transparent, input-masked screen allocation for the bar and its open popup.
`PunchiTopBarView` is the Qt Quick presentation and emits the intents the shell
forwards; `PunchiTopBarPopup` is the shared popup policy; the calendar and the
quick-controls card live in this module too.

`shell.qml` composes one bar per screen in `PunchiScreenPolicy.activeScreens`
while `topBarEnabled` is on. `services/PunchiTopBarServices.qml` owns the shared
clock and the provider adapters, and `adapters/kde/` owns every desktop call.
The settings switch is `PunchiTopBarSettingsCard` in `modules/settings/`.

Later phases (brightness, do-not-disturb, media, session actions, application
menu, notifications and widgets) are not implemented.
