# Top panel

An optional bar at the top edge of the selected screens. It is off by default and
is enabled with **Settings → General → Show top panel**. Enabling, disabling,
saving and discarding follow the same draft, Apply, Accept and Close rules as the
rest of the settings window, without restarting Punchi.

```text
[Punchi]                                  [Search] [Quick controls] [Clock]
    └─ Applications, Dock settings                 └─ Volume, Wi-Fi, Bluetooth, USB
                                                          └─ Calendar
```

The bar follows the active Plasma palette and icon theme. It is a separate
Quickshell layer surface, not a Plasma panel: Plasma keeps owning its panels, the
system tray, notifications and polkit, and Punchi never loads a private tray
container or registers a second session service.

## Placement and lifecycle

- One bar exists per screen allowed by the dock's screen selection, including its
  primary-screen fallback. The bar appears on every virtual desktop and activity
  of those screens, independently of the dock's automatic hiding.
- The bar is anchored to the top edge and reserves its logical height while it is
  visible, so maximized windows start below it.
- The surface stays transparent and input-transparent outside the bar and the open
  popup. Popups are clamped inside their screen.
- Turning the switch off, removing a selected screen or stopping Punchi destroys
  the corresponding window, its popups, subscriptions and reserved area.

## Contents

| Control | Behavior |
| --- | --- |
| **Punchi** | Compact menu with **Applications**, which opens the existing fullscreen PunchiMenu on the screen that owns the button, and **Dock settings**, which opens the existing settings window |
| **Search** | Opens KRunner once per gesture through its `org.kde.krunner` D-Bus interface, falling back to the fixed `krunner` executable when no instance owns the name |
| **Quick controls** | Brightness, volume and mute, the current MPRIS player, Do Not Disturb, Wi-Fi, Bluetooth and removable storage, plus links to the KDE settings modules that own configuration Punchi does not implement |
| **Clock** | Time and date from the system locale and time zone, with a monthly calendar that starts on the current month and offers Previous, Next and Today |

The quick-controls card is pinned to the right margin of its screen. Any open
popup closes with Escape or an outside click and returns focus to its trigger. Only one popup is open at a time. Icon-only triggers keep their
accessible names, the clock always exposes its full date and time to assistive
technology, and the bar keeps every action when it is too narrow to show labels.
The only bar animation is a short hover fade, disabled when reduced motion is on;
popups do not animate.

## Quick controls

Each control reads a public provider and reports only what that provider
confirms. A requested change stays pending until the provider reports the new
state; a provider that fails or never answers keeps its previous state and shows
an explicit short result instead of claiming success.

| Control | Provider | Behavior |
| --- | --- | --- |
| **Brightness** | PowerDevil `org.kde.ScreenBrightness` | Shows the internal display first, otherwise the first display with a real range; the slider is clamped to the provider range, the value is read back after the write, and a missing provider or display leaves the row disabled |
| **Volume and mute** | Quickshell's PipeWire service (`Pipewire.defaultAudioSink`) | Acts on the ready default sink, reflects external volume and mute changes, keeps mute independent from volume, mirrors an amplification the provider already reports, and refuses a late slider value when the sink identity changed during the gesture |
| **Now playing** | Quickshell's public MPRIS service | Picks a playing player first, otherwise the first controllable one; shows its announced title/artist and only the transport actions it reports; the section disappears when no player exists |
| **Do Not Disturb** | Plasma's `org.freedesktop.Notifications` `Inhibited` property (read-only) | Shows the effective mode and opens Plasma's notification settings. Plasma exposes no public setter for its persistent mode, so the row deliberately has no local switch |
| **Wi-Fi** | Quickshell's NetworkManager provider (`Quickshell.Networking`) | Reflects the confirmed radio state, hardware block, connection and network name; a new network and its credentials stay in Plasma |
| **Bluetooth** | Quickshell's BlueZ provider (`Quickshell.Bluetooth`) | Reflects adapter presence, power and the provider's Blocked state, handles several adapters through the provider default or first adapter; **Pair** opens KDE's pairing wizard, so discovery and the BlueZ agent stay in KDE |
| **Removable storage** | UDisks2 D-Bus | Lists provider-identified removable drives with a visible filesystem; **Unmount** removes one mounted visible filesystem, while **Safe to remove** unmounts every visible mounted filesystem of a drive and is unavailable while a hidden or system volume remains mounted |

**Safe to remove** never forces an unmount, ejects media or powers a drive off.
Hidden and system volumes are not rows, but their mounts still block whole-drive
removal; a per-volume action remains limited to its visible volume. Success is
reported only after a fresh UDisks2 snapshot confirms that no relevant filesystem
of the drive remains mounted. Busy, protected, rejected, timed-out and disconnected
results are reported separately and the device stays listed for another attempt.

The KDE settings links open the network, Bluetooth, sound and removable-device
modules with fixed identifiers. Bluetooth pairing opens the KDE pairing wizard.
These are complementary accesses, not replacements for the native Plasma applets.

## Limits

- Brightness, do-not-disturb, media transport, session actions, the application
  global menu, notifications and additional widgets are later phases and are not
  part of this panel.
- The panel does not read or change plasma-pa's amplification preference: it
  mirrors a boost the provider already reports and never introduces a higher
  maximum by itself.
- Do Not Disturb is read-only: Plasma owns the notification server and exposes
  only the effective `Inhibited` state. Punchi never registers as a notification
  server or a second DND owner; the row delegates configuration to
  `kcm_notifications`.
- Playback uses the session MPRIS list, not the dock's app-scoped adapter. With
  several players it prefers one that is playing, otherwise the first
  controllable player; artwork, seeking and playlist selection are not part of
  the row.
- Brightness comes from PowerDevil; Punchi never writes `/sys/class/backlight`.
  An external display appears only when PowerDevil reports a controllable range
  for it, and a session without PowerDevil disables the row.
- Physical USB removal, real Bluetooth pairing and a physical audio-device swap
  are not automated by the test suite. Hardware block, adapter absence and
  adapter power are observed through the providers.
- The bar coexists with the running Plasma panel on the tested session, which is
  not at the top edge; a Plasma panel at the top edge and multi-screen hot-plug
  remain manual session observations, not claimed here.
- A plain fullscreen window covered the screen and KWin hid the bar; a maximized
  window started below the reserved band. Video, presentation and multi-screen
  fullscreen paths remain unvalidated.

## Validation

The behavior is covered by QML tests for the bar, menu, calendar and every quick
control, by the adapter contract probe and by a real-compositor session probe
that mounts the bar, checks one surface per screen with its exclusive zone, and
verifies that disabling the switch releases it. Screen capture, theme and
physical-device checks are recorded in the private development record. The
captures use the system Qt Quick Controls style, not an offscreen substitute.
Brightness is validated against the live PowerDevil service read-only; a provider
write and a physical sweep confirmed the native path. Playback is covered by QML
doubles and by two owned MPRIS players on a private bus, where the playing player
wins and only its announced commands are dispatched. A visual capture with a real
player and the broader physical checks remain pending. The
session evidence comes from one Fedora 45 machine with Plasma/KWin 6.8.3, KF6
6.32.0 and Quickshell 0.2.1; it is an observation, not a new compatibility row.

## Related pages

- [Settings](../configuration/settings.md#categories): the General switch and its
  first-run default.
- [Desktop integration](desktop-integration.md): coexistence with Plasma.
