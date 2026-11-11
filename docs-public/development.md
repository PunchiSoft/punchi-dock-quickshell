# Development and testing

## Runtime

Install a distro Quickshell package compatible with its Qt libraries. On the
observed Fedora environment, the user installed it with `sudo dnf install quickshell`.
Check the actual version using `qs --version`; do not assume current website docs
match the installed release. This configuration first targets the 0.2.1 API.

`./scripts-user/setup.sh` opens the guided setup menu and also accepts
non-interactive actions such as `--check-deps`, `--install`, `--build`,
`--try`, `--uninstall` and `--start`. `--try` (alias `--test`) builds the
checkout and runs it from the checkout without installing; `--start` only runs
an existing build or user-local installation. A trial exports
`PUNCHI_PROFILE_DIR` so `PunchiSettingsStore` and `PunchiAutostartService` use a profile under
`$XDG_RUNTIME_DIR/punchi-dock-quickshell-$UID/trial-profile`, which keeps the
installed copy's preferences and autostart entry untouched and disables the
autostart switch. When the dock exits, including after Ctrl+C, one confirmation
removes the build output, the trial profile, the window-state registration and the
runtime lock. A trial refuses to start while this checkout is already running, and
the cleanup skips a running copy, so an open dock never loses its build output or
registration. Uninstall asks one question with two answers: keep the data (the
previous build and preferences questions) or remove everything, which also drops
the legacy `punchi-shell.json`, the runtime lock and the window-state
registration. Both paths unregister
`${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.punchi.Shell.WindowState.desktop`
through the native backend and delete it when its content still matches this
project. Install and build offer to install
missing dependencies before compiling. Fedora package names are validated;
Debian/Ubuntu and Arch maps are best-effort. Debian stable does not carry
Quickshell, so when it has no apt candidate the setup offers to add the matching
`<codename>-backports` source with an explicit confirmation and installs
`quickshell` from it; declining keeps the remaining packages installable. The
setup checks
`kbuildsycoca6`, `plasmashell` and `kwin_wayland`, and reports that KDE
Plasma/KWin on Wayland is required. A failed build writes a timestamped log
under the user's Documents directory. The assistant builds the checkout, can
install the runtime for the current user under
`${XDG_DATA_HOME:-$HOME/.local/share}/punchi-dock-quickshell`, and writes an
application-menu launcher with Stop and Settings actions. It never stops or
restarts Plasma.

Setup presentation is split into three libraries under `scripts-user/lib/`:
`setup-terminal-ui.sh` owns the style codes, the boxed header and the phase
lines; `setup-resources.sh` reports RAM, CPU cores and the RAM-capped build job
count; `setup-progress.sh` owns the single-line progress runner. The header and
the moving bar are drawn only on a UTF-8 terminal, and every long step keeps its
full output in a log file so a failure can attach it. Build concurrency is the
detected CPU count capped by installed memory (1 job below 4.5 GiB, 2 below
8.4 GiB, 4 below 16 GiB); `-j/--jobs N` overrides it and
`PUNCHI_NO_PROGRESS=1` prints the raw command output.

`cmake --install "build/build-<ID>" --prefix <prefix>` provides a second, packaging-oriented
layout: `bin/punchi-dock-quickshell`, QML under `share/punchi-dock-quickshell`,
the native QML plugin and its `libpunchikde.so` implementation library under
`share/punchi-dock-quickshell/qml/Punchi/Kde`, the backend under
`libexec/punchi-dock-quickshell`, a desktop entry and a
hicolor icon. `cmake --build "build/build-<ID>" --target uninstall` removes the recorded
files; `cpack` creates a portable TGZ.

The QML plugin loads `libpunchikde.so` through a `$ORIGIN`-relative run path, so
both layouts resolve the library from their own tree. The user-local install
copies that library into its `build/` directory. Never rely on an absolute path
into the developer checkout: a running installed copy would break with
`<Type> is not a type` whenever the source build is relinked or replaced.

Run `./scripts-user/start.sh` from the checkout. It remains in the foreground and
prevents a duplicate configuration instance. The same runtime lock prevents a
source-checkout and a user-local installation from running together; the second
start reports the active path and its restore script. Stop with Ctrl+C or run
`./scripts-user/restore-kde.sh`. Neither script edits or restarts Plasma. The
installed copy exposes the same `start.sh`, `restore-kde.sh` and `settings.sh`
under its install root.

Quickshell's built-in reload popup is suppressed after a successful reload by
`Quickshell.inhibitReloadPopup()` in `shell.qml`. The popup loads Quickshell's
own wrapper components, which log Qt property-cache warnings with the installed
Qt version, and it duplicates information the log already records. A failed
reload still shows its popup with the error text. To inspect reload outcomes,
read the instance log instead of relying on the popup:

```bash
qs log --path ~/.local/share/punchi-dock-quickshell -t 40
```

## QML editor setup

Follow the [official Quickshell setup guide](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
for the installed release. For VS Code, use Qt's QML extension and enable
`qt-qml.qmlls.useQmlImportPathEnvVar`. Create an empty `.qmlls.ini` beside
`shell.qml`; Quickshell fills it with machine-specific settings on startup.
This file and `.vscode/` are ignored. Keep custom editor overrides in workspace
settings rather than changing preferences for unrelated projects.

Build the native module first. If the editor cannot resolve imports, inspect its
actual server executable and arguments in the QML Language Server output. A
downloaded standalone server may not know the distro's Qt/KDE import directory.
Find that directory with `qtpaths6 --query QT_INSTALL_QML` (or the equivalent
tool from the active Qt installation). Select that installation's `qmlls` using
`qt-qml.qmlls.customExePath`; add the discovered system QML directory and this
checkout's `build/qml` to `qt-qml.qmlls.additionalImportPaths`. The extension
supports `${workspaceFolder}/build/qml`. Keep absolute machine paths local.

After changing the setup, run the extension's `Qt: Restart QML Language Server`
command. This affects the editor only. Follow [Qt's language-server documentation](https://doc.qt.io/qt-6/qtqml-tooling-qmlls.html)
for build/import configuration and verify flags against the installed `--help`.
Enable `qt-qml.qmlls.useNoCMakeCalls` when building explicitly through CMake, so
the editor does not trigger extra rebuilds.

An editor Problems count is not interchangeable with configured lint or runtime
evidence. Keep the documented metadata gaps below visible; do not change valid
Quickshell window syntax merely to silence a language server.

## Developer checks

Folder validation adds `folder_contents` for the real KDirModel/sort/action-row
pipeline, `folder_container` for Grid/List/Detail/Fan rendering, navigation,
the Home standard-XDG filter with an owned localized home, rejected opening,
keyboard/lateral placement and draft synchronization, and the
`FolderFan` QML tests for the arc law, the height ceiling, edge orientation,
reduced motion and the absence of a surface behind the rows. Tests use owned temporary
Downloads and Home content and private D-Bus sessions. Native addition/rename notifications
and KIO deletion update the model; close cancels listing. File-opening UI tests
use a recording opener and do not launch user files. The existing KIO launching
tests cover the shared dispatch pipeline; physical MIME-app activation remains
a separate check. The optional `--capture` argument to folder_container_test.py
retains explicitly requested developer previews under the record evidence directory;
normal CTest leaves no captures. `scripts-dev/prune-evidence.py` reports evidence no
record cites that is older than the retention window, and `--apply` deletes it. The
captures are kept in the private evidence record.

The folder popup also checks its close control, the shared last Open row, the
slim scroll indicator and its reserved gutter, the chevron of a browsable
directory, and the entry menu with Copy Path.
Its native KWindowEffects blur is unavailable to offscreen tests; inspect the
translucent surface and blur shape in a real KWin session.

Trash validation adds `trash_state` (native injected listers/jobs) and
`trash_runtime` (real Quickshell, KDE application style, fake destructive
operations). Never use an automated emptyTrash call against actual `trash:/`:
changing XDG_DATA_HOME does not isolate every mounted-volume trash location.
Component checks cover menu controls, confirmation, ordering, schema migration,
interrupted exit and reduced motion. Existing application-editor expectations
include the additional default item; the app-only reorder fixture remains
explicitly scoped to its original eight application rows.

The application context now also imports the installed Plasma private MPRIS QML
module (`org.kde.plasma.private.mpris`, observed Plasma 6.7.5). Its private API is
isolated in an adapter and other versions require validation. Application identity
resolution additionally links KF6 CoreAddons for safe desktop Exec token parsing.
`application_media` tests the actual KDE provider and menu with owned player
processes on a private bus; `task_identity` seeds owned desktop metadata and checks
listing, marker identity and activation/minimization without launching apps.
The media interaction waits for the command the popup recorded and, separately,
for the service to reflect it, so a click that never lands is reported as a
missing click instead of as a media failure. The settings-window interactions
capture the row or entry reference inside the wait, because the asynchronous list
model can rebuild between a lookup and its use.
The hover regression distinguishes pointer fill from keyboard visual focus and
executes Enter through the actual shared row. Screen-reader and physical-session
visual checks remain separate.

Requirements: Python 3, CMake 3.22+, Qt QML tooling/Quick Test, Quickshell type
metadata, Kirigami, KDE QQC2 Desktop Style, the KDE Qt platform-theme plugin,
Kirigami Addons components, the CoreAddons QML module (`org.kde.coreaddons`),
and an installed icon theme. Ninja is used in this documented workflow.
Running markers additionally build a dedicated window-state executable using
Wayland client development headers/library (`wayland-devel` on Fedora), Qt's
public native Wayland interface and the installed KDE taskmanager QML module.
No direct LibTaskManager C++ development target or private Qt API is introduced.
The native launch module additionally requires a C++17 compiler, Qt 6 Quick/QML
development packages, and KF6 KIO, Service, and WindowSystem development packages.
The context menu and recent applications also require Plasma Activities Stats and
Plasma Activities development packages (`plasma-activities-stats-devel` and
`plasma-activities-devel` on the observed Fedora system, version 6.7.5).
Native Places also links KIOFileWidgets from the existing KIO development package.
WindowSystem 6.19+ supplies the per-request activation-token future API. The
observed build uses Qt 6.11.2 and KF6 WindowSystem 6.30.0; other combinations
require validation. No native module is installed into system directories.

```bash
cmake -S . -B "build/build-$(. /etc/os-release && printf '%s' "$ID")" -DBUILD_TESTING=ON
cmake --build "build/build-$(. /etc/os-release && printf '%s' "$ID")"
ctest --test-dir "build/build-$(. /etc/os-release && printf '%s' "$ID")" -L 'unit|qml' --output-on-failure
```

The user setup writes one tree per distribution under the shared `build/`
directory, `build/build-<ID>`, so testing several systems never reuses another
distribution's objects or caches and the checkout keeps one ordered tree
directory. The flat `build-<ID>` and plain `build/` trees of the earlier layouts
are still read when they are the only complete ones. `PUNCHI_BUILD_DIR`
overrides the location. `cmake --preset dev` keeps the generic `build/dev` path
that CI uses, so it is the single-distribution route.

`ctest -L 'unit|qml'` selects the `unit` and `qml` labels without a
compositor; the full command adds the `session` label that needs the live
Plasma/KWin Wayland session. CI runs `scripts-dev/ci-headless.sh` inside Fedora 44
with the presets and never claims session or visual validation.
`project_version` compares the tracked version declarations with the newest
changelog heading.

The CI image is pinned by digest in `.github/workflows/ci.yml` so a refreshed
base cannot change the graph without a reviewable commit; the Fedora packages are
still resolved on every run. Refresh the digest with

```bash
curl -s https://hub.docker.com/v2/repositories/library/fedora/tags/44 \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["digest"])'
```

A failing run publishes `build/ctest-junit.xml` as an artifact, and
`scripts-dev/report-junit-failures.py` turns it into one annotation per failing
test, because the job status alone says only that something failed. The
`.github/workflows/stability.yml` runs on a schedule and on demand with
`PUNCHI_CTEST_REPEAT=until-fail:10` over the interaction tests: repetition is the
only measurement of a flake rate that a single pull-request run cannot give. It is
a separate workflow so a check that never applies to a pull request does not appear
as a skipped one, and it repeats `FEDORA_IMAGE` because workflows cannot share
`env`.

`test_timing_contract` holds two rules that came from real failures — a delegate
resolved again after a wait, and a wait budget above the 35-second isolated-runner
deadline — and `flaky_quarantine` validates `tests/flaky-tests.json`, which stays
empty unless an entry carries an open issue, a reason and an unexpired date. The
headless script excludes quarantined tests from the blocking selection and re-runs
them where a failure warns instead of failing the pipeline.
`project_foundation` also guards the outbound reuse terms: every `SKILL.md` keeps
its `license` field and the skill catalog keeps its `Reuse and attribution`
section, so a copy of a skill always carries the notice it depends on.

CMake builds `Punchi.Kde` under the build tree's `qml` directory and configures
the validation graph. The start script adds that directory to QML_IMPORT_PATH.
Rebuild after changing
native code and stop/restart Punchi Dock Quickshell to load the new library; Plasma remains
running. Settings continue to update live without rebuilding.
CTest includes QML lint against documented upstream metadata gaps, Qt/Kirigami dock
interaction tests, an isolated Quickshell desktop-entry launch test, window-access
classification contracts, portable foundation checks, and `architecture_contract`.
That last test reads the quoted relative imports of `components/`, `config/`,
`services/`, `modules/` and `adapters/`, and fails when a layer reaches a layer it
must not know about (`services` to `modules`/`components`, `adapters` to any
internal layer, `components` or `config` to `modules`/`services`, and `config` to
`adapters`). It also rejects an import that resolves outside the repository, a
root-level `property` or `function` in `shell.qml`, a `shell.qml` over the drift
limit, and a stale entry in `tests/architecture-allowlist.json`. The gate runs on
the source tree, needs no Qt, and takes well under a second. The single
allowlisted edge is `config/PunchiShellSettings.qml` reading
`adapters/kde/PunchiMotionPreferences`; removing it would need a service in between and
is a separate change. Tools are discovered on PATH or conventional Qt 6 tool paths.
The application-items test builds an owned KDE service cache and runs the actual
settings editor with synthetic pointer/keyboard input. It checks search, preview,
draft cancellation, duplicate/hidden/unknown rejection, live dock insertion, ID
persistence, reset, container Grid/List/Detail selection, Trash singleton and
remove/re-add behavior, and launching an owned sentinel through KDE/KIO. User
desktop entries and applications are never modified/launched. The existing KIO
warning about the absent systemd user manager on an isolated bus remains visible;
every other UI/runtime warning fails this test. Native theme tests also exercise
editor hosting in the actual settings window and cancellation on window close.
Settings editing tests exercise the actual Apply/Accept/Close controls, keyboard
activation, pending reset and item removal, reopen, sidebar/footer placement and
live pin consumers.
Owned application tests additionally check additions stay pending until saved.
New window tests retain the exact offscreen QPA `raise()` limitation as a visible
diagnostic; all other unexpected UI warnings fail, and the older editor test's
warning checks remain unchanged.
The application-picker regression checks results height, left-aligned labels and
value columns, native selected metadata and action placement. Item-order checks
drive actual arrow buttons, keyboard activation, bounds, retained selection and
pending Apply/Close behavior. The configuration-runtime test uses the production
shared controllers with a real Quickshell FloatingWindow and settings window:
temporary reveal, layer policy, mode restoration, reservation, Apply and prior
visibility. Quickshell has no PanelWindow backend offscreen, so this test does not
establish actual layer-shell placement or KWin stacking.
The settings-theme test runs offscreen on an isolated bus with the real settings
window and the production startup pragmas. It verifies native KDE style discovery,
owned light/dark Window palettes, fonts, live control bindings, close/reopen, and
an explicit Qt Quick Controls style override. It also verifies Apply reaches the
owned PunchiSettingsStore JSON and discarded edits never do. It avoids portal activation in its
owned environment. This is separate from KWin/theme visual confirmation.

The dock's comic tooltip selects `Kirigami.Theme.Window` without inheriting a
launcher's color set, matching the existing context-menu profile. Background and
border reuse PunchiBalloonSurface's theme defaults; text consumes the same Kirigami
Window role. The approved silhouette, pointer, inherited system font, metrics,
tracking and hover/focus lifecycle remain unchanged. No separate Plasma tooltip
color provider or additional libplasma build dependency is introduced.

`tooltip_theme_runtime` renders the actual tooltip and context-menu surfaces on
a private bus. Owned KDE Window palettes deliberately differ from Tooltip
palettes. It checks equal background/text/border across light/dark/light changes,
the same balloon instance, font, body/tail pixels and transparent corners.
The KDE platform theme handles the existing palette-change notification;
Kirigami bindings update both surfaces. No custom polling or runtime notification
bridge is needed. See the [KDE platform-theme implementation](https://invent.kde.org/plasma/plasma-integration/-/blob/Plasma/6.7/qt6/src/platformtheme/khintssettings.cpp).
Component tests retain icon tracking, focus and open/close assertions. Every
unexpected runtime warning remains a failure. Physical desktop switching and GPU
rendering remain separate from these offscreen checks.

The recent-documents test additionally uses Python D-Bus and PyGObject bindings
for an owned ActivityManager fixture on an isolated bus. It seeds a temporary
SQLite database and checks app/activity scope, latest-five ordering, local URL
launching, native query-scoped history clearing, and reactive unpin settings.
The Places test also runs offscreen on an isolated bus. It creates owned desktop
entries and bookmarks through the real KFilePlacesModel, verifying category scope,
hidden rows, native names/icons, grouped expansion, the >7 threshold, selection
reset, reactive bookmark editing/removal and KIO opening of a local URL containing
spaces and non-ASCII characters. Component tests exercise More/group/back without
closing the popup or resizing its host, keyboard activation, recent-section
fallback and activation before dismissal. User bookmarks are not modified.
The launch test runs on an isolated D-Bus session, with startup feedback disabled
for its owned sentinel desktop files. It waits for KIO results and checks failed
executables as well as rejecting paths and command-like IDs.

The real-session test is explicit and requires an active Wayland session:

```bash
python3 scripts-dev/verify-session.py
python3 scripts-dev/verify-panel-modes.py
python3 scripts-dev/verify-settings.py
python3 scripts-dev/run-isolated.py --session -- python3 tests/launch_runtime_test.py --window
```

The runners keep writable XDG homes temporary, select the KDE platform theme for
named icon resolution, and expose installed user icon assets through read-only
lookup directories. The session test creates a link to the current Wayland
socket. It exercises the real entry point, duplicate prevention, scoped restoration,
and a bounded surface render/hide/reopen probe. Cleanup belongs to a parent runner.
It also checks that restoration preserves an unrelated Quickshell configuration.
The panel-mode probe checks slide position relative to `restingSceneY`, the fixed
bottom dock viewport within the larger transparent client area.
It does not modify session configuration or reserve additional screen space.

Native running-state tests cover KDE role aggregation, last-window removal,
streamed native-provider updates, invalid snapshots, unknown versus empty state,
EOF shutdown, scoped hidden registration and collision refusal. The offscreen
running-marker test drives an owned producer through the native provider and
real application catalog into the actual dock. Its desktop entry is never launched.
Actual dedicated-backend access on KWin remains a separate manual check.

## Evidence levels

Component tests cover selection intent, keyboard navigation, Escape, hover/focus
separation, live metrics, model mutation, and recreation. Wave checks also cover
source-formula samples, stable icon resolution, lifted hit targets, balloon
placement, horizontal background expansion at both ends, and reduced motion. They do not establish
actual KWin placement or visual quality. The session test checks connection,
rendered frames, and lifecycle; it does not replace manual inspection of appearance,
monitor changes, scaling, or theme variants.

Inspect those visually before approving a visual stage. Window tracking, global
shortcuts, desktop services, auto-hide, and exclusive space reservation need future
integration tests. Use isolated provider data and unique temporary state. Do not
weaken tests or suppress warnings to obtain a green result.

## Quickshell startup log noise

Status recorded on 2026-10-29 with Quickshell 0.3.0 from Debian 13
(trixie-backports) on Qt 6.8.2 and Plasma 6.3.6. The dock logs one line at
startup:

```text
WARN: QSettings::value: Empty key passed
```

It is not produced by this project. Reproducing steps and evidence:

- A two-line configuration (`import Quickshell` plus `QtObject { }`) emits it
  before `Configuration Loaded`, so no project QML is involved.
- The Debian original source of Quickshell 0.3.0 contains no `QSettings`
  reference at all (`grep -rin QSettings` returns nothing), so Quickshell does
  not read settings directly; a Qt or KDE component it initializes does.
- `QT_QPA_PLATFORMTHEME=generic` and the `Basic`, `Fusion` and
  `org.kde.desktop` Qt Quick Controls styles all keep the warning, so it is
  neither the platform theme nor the widget style.
- A plain Qt Quick runtime (`qmltestrunner` with a trivial test) does not emit
  it, so it belongs to the Quickshell startup path.
- The only `QSettings` in this project is
  `adapters/kde/native/appearance/iconthemecatalog.cpp`, which skips empty directory
  entries before using them.

The line is cosmetic, appears once per start and changes nothing. It is recorded
as a known limitation in the public README. `QT_LOGGING_RULES=default.warning=false`
does silence it, but that also hides every uncategorized `qWarning`, including
the ones from the project's own adapters, so the project does not set it. Qt
gives this message no logging category, so there is no narrower filter.

## Quickshell 0.2.1 type metadata gaps

Status recorded on 2026-10-13: three known tooling diagnostics remain with
Quickshell 0.2.1 and Qt 6.11.2 on the observed Fedora environment. After fixing
the editor's server and import paths, its remaining diagnostics match configured
lint. These are unresolved upstream metadata defects, not corrected project bugs.

On Fedora's installed 0.2.1 package, `Quickshell/_Window/quickshell-window.qmltypes`
exports `PanelWindowInterface` as `PanelWindow` with `isCreatable: false` (lines
123–128), although the Quickshell executable registers a usable platform window.
Its `margins` property refers to `Margins` (lines 140–144), a value type exported
by core metadata as lower-case `margins` (core file, lines 604–611). Qt 6.11's
standalone lint cannot completely resolve this relationship.

The official [PanelWindow documentation](https://quickshell.org/docs/v0.2.1/types/Quickshell/PanelWindow/)
supports window creation and `margins.bottom`; actual Quickshell/KWin loading,
frame rendering, hide/reopen, and shutdown pass. Keep the valid runtime syntax.
Assigning a JavaScript object to `margins` fails at runtime and is not a workaround.

The remaining messages in `modules/dock/PunchiDock.qml` are:

| Diagnostic | Category | Explanation |
|---|---|---|
| `Type PanelWindow is not creatable.` | `uncreatable-type` | Static metadata describes the abstract interface as uncreatable; Quickshell supplies a usable platform implementation at runtime. |
| `unknown grouped property scope margins.` | `unqualified` | The analyzer cannot resolve the grouped value-type property from the installed metadata. |
| `Type margins is used but it is not resolved` | `unresolved-type` | The same unresolved value type prevents analysis of `margins.bottom`; this is not a separate margin-placement failure. |

The official [0.2.1 setup guide](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
acknowledges the `PanelWindow` language-server limitation. The upstream
[issue #543](https://github.com/quickshell-mirror/quickshell/issues/543) also
reports the creation-metadata mismatch. The two `margins` diagnostics above are
confirmed from this installation; the issue is not evidence for every diagnostic
or every Qt/Quickshell combination.

### Quality policy and resolution

The goal is zero warnings and correct behavior. Until upstream metadata resolves
these cases, require zero additional diagnostics and retain these exact exceptions
in [the baseline](../tests/qmllint-upstream.json). Lint prints every warning and
rejects additional files, messages, categories, or duplicates. Acceptance is
limited to the documented signatures, not an entire warning category.

Preserve the valid `PanelWindow` and grouped `margins.bottom` runtime syntax.
Do not disable checking, fabricate replacement types, patch installed metadata,
or switch window implementations solely to clear the editor counter. A modified
tooling description that stops reporting a warning does not establish that the
upstream defect has been fixed. Keep runtime warnings and behavioral regressions
subject to their existing test checks; these static exceptions do not excuse them.

When updating Quickshell or Qt:

1. Record the actual versions and verify the editor uses the corresponding Qt
   tooling and installed/native import paths.
2. Build the project and run `ctest --test-dir build --output-on-failure -R '^qml_lint$'`.
   Compare complete messages and categories with the existing baseline.
3. Remove only exceptions that no longer occur with upstream metadata. Investigate
   changed or new diagnostics before modifying the baseline.
4. Validate shell loading, margins, visibility transitions and shutdown in the
   authorized environment. Treat real KWin/visual checks as separate evidence.
5. Update this status and record the tested versions and results. Do not claim
   zero warnings until both configured lint and the refreshed editor confirm it.

Known tooling exceptions do not prove that the dock has no other bugs. Static
analysis, runtime checks, behavioral tests and desktop validation remain separate
requirements.

The launch tests create a private desktop entry and a short-lived Python sentinel.
They validate argument parsing, repeated dispatch, missing-entry rejection, and
actual dock-to-service wiring without opening user applications. The sentinel's
exact script path identifies detached children for cleanup; writable data stays
inside parent-owned temporary state. Manual opening of the configured applications
is separate evidence, especially for single-instance applications and KDE startup
integration. Dispatch does not mean the application's window is ready.

For the initial KDE window-access check, run
`python3 scripts-dev/probe-kde-windows.py`. The probe reports its structured states
and the observed standalone permission limitation. This diagnostic does not change dock visibility.

Dock interaction tests cover captured icon geometry, Configure/desktop-action
intents, Escape, shared balloon geometry and magnification while a menu is open.
Pointer regressions open the actual menu, hover another launcher, activate it with
one click, retarget via right-click and cancel a pending popup. A Qt window fixture
checks tall-menu allocation, fixed dock baseline/height, retargeting while expanded,
and a single click on another launcher before releasing that allocation.
The revealed production window now uses stable monitor-bounded allocation.
A separate regression repeatedly changes menu contents and opens/closes it while
checking zero window resizes, unchanged dock baseline and sustained magnification
without another pointer move. Geometry tests cover margins, missing screen data,
auto-hide edge size and live monitor changes. Larger transparent window buffers
are a tradeoff; offscreen tests do not measure compositor/GPU cost.
A separate offscreen Quickshell runtime test loads the actual popup, verifies its
same host QQuickWindow, nonmodal item popup, icon-relative placement and pointer,
opens/closes/reopens it, checks action
routing before dismissal and rejects the two reported startup warnings.
Offscreen window-mask limitations remain visible. This does not establish actual
KWin placement, input regions, startup cursor feedback, or theme variants.
Desktop-action tests discover and execute an owned sentinel action through KDE,
rejecting hidden and unknown actions without opening user applications.

The menu uses the public Qt Quick Controls `Popup.Item` API (introduced in Qt 6.8).
It shares the dock scene to preserve hover and click delivery to other launchers.
The observed build uses Qt 6.11.2; earlier Qt versions require validation.
The documented lint baseline remains unchanged.

## Resolved Plasma popup startup diagnostics

Qt 6.11.2, libplasma 6.7.5 and KF6 6.30 reproduced a cross-thread KDE
language-watcher warning and a PlasmaQuick::Dialog visible-property override.
The menu now uses a Qt Quick Controls item popup in the dock window. No private PlasmaQuick C++ wrapper, early-load bootstrap, warning
filter, or modified system library is used. English fallback remains the only
supported project language. Real Wayland behavior still requires manual checks.

## Native auto-hide edge

Building now requires `wayland-scanner` and libwayland-client headers; protocol
XML descriptions are bundled with upstream notices. `BUILD_TESTING` additionally
requires libwayland-server headers for the owned compositor fixture. No Qt private
headers or additional desktop-entry permissions are needed for the edge sensor.

`autohide_edge` runs an isolated Wayland server and checks actual layer/edge
requests, matching output, no focus/reservation, input release, rearming, resize,
unsupported capability fallback, closure and cleanup. New motion component cases
check KDE durations, endpoint completion, repeated reversal, instant mode and
visual travel independent of unused top headroom. They preserve existing tests.

The native sensor requires named `wl_output` version 4, pointer input, layer-shell
version 3 and KDE's desktop-internal screen-edge extension. The adapter has no
blocking roundtrips and no animation polling. If those capabilities are absent,
the local hover strip remains available. The sensor is pointer-driven; native
touch-gesture reveal is not implemented in this stage. Monitor hotplug, edge
conflicts, screen lock, fractional scaling and native glow visibility require
manual KWin validation. The theme's glow effect can be disabled independently;
edge support does not guarantee that the glow is enabled.

The dock slide remains QML-rendered to keep the existing stable menu allocation.
It follows KDE's default cubic profile/duration, not custom KWin Sliding Popups
configuration. These tests do not establish frame pacing or native visual parity.
After rebuilding a native module, stop only this configuration with
`./scripts-user/restore-kde.sh`, then run `./scripts-user/start.sh`. Do not restart
Plasma or alter its panels. Previously restricted real-session checks remain
separate from the offscreen suite.

## Window dodge and Showing Desktop

The `window_models` test loads the exact embedded KDE model resource and checks
native object extraction, visibility filters and unavailable offscreen geometry.
`running_state` now also checks the independent geometry channel, Showing Desktop,
negative monitor coordinates, minimized/hidden/helper exclusion, malformed bounds,
streamed geometry-only updates and shutdown. `window_dodge_runtime` uses actual
Quickshell, native parsing and production services/controllers with an owned
producer on an isolated bus. It checks native model filter configuration,
nonintersection, desktop transitions, interaction holds and unavailable fallback.
Component checks additionally cover keyboard mode selection, persistence, reduced
motion, resting geometry and the preserved auto-hide policy.

The native edge request regression now requires scope `dock`; this is the
corrected KDE classification contract. Fake compositor checks prove the request,
not KWin's Showing Desktop handling. Main-window type recognition, physical
geometry, edge reveal after Super+D and multiple-monitor desktop/activity behavior
still need manual session validation. The registered settings_reload issue remains
separate and is not disabled to validate this feature.

The two model-loading tests use an owned D-Bus configuration without host service
auto-activation directories, so ActivityManager lookup cannot launch a desktop
daemon during validation. Their parent wrapper owns the process group and bus
configuration and removes them after shutdown. The actual native model resource
loads offscreen, but that platform supplies no window source/roles; geometry role
serialization is covered with owned model rows, and live roles remain a KWin check.

## Activate existing windows

`window_activation` covers native model selection/dispatch, the actual offscreen
backend command reader, partial records and EOF, provider correlation, timeout
and loss. `window_models` also verifies requestActivate metadata on the actual
embedded TasksModel. `window_activation_runtime` uses actual Quickshell click
intents, the native pipe domain and KIO launch of owned sentinel applications.
Both added integration groups use parent-owned temporary directories and a private
bus without host service activation. No real window is raised by these checks.

The window-activation reference documents request/result and stage limits.
After rebuilding, restart only Punchi Dock Quickshell to load the updated native module.
Validate an existing, minimized, already-active and multiple-window application
manually in KWin, plus a closed app and explicit New Window. The registered
settings_reload failure remains separate from the allowed isolated selection.
An eligible already-active window now takes KDE's requestToggleMinimized path;
fixtures check active/minimized/non-minimizable states and the typed minimized
reply through the real provider and Quickshell coordinator.

## Basic task manager contracts

`dock_applications` exercises the native model with QAbstractItemModelTester,
pin/running/catalog changes, deduplication, persistent indices and source loss.
`application_catalog` writes an owned browser and editor plus a `mimeapps.list`
default into isolated XDG directories, rebuilds the KDE cache, and checks that a
role catalogue row publishes the resolved desktop id and application icon, walks
the ordered MIME types, keeps the preset icon when nothing answers, and rejects a
malformed type.
Component tests verify middle-click has a separate New Window intent, keyboard
activation is unchanged and focused-item removal transfers focus. Startup tests
cover pending coalescing, native starting replies, accepted-launch reservations,
failure, observed windows, expiry and explicit New Window bypass. Native activation
tests cover group cycling and actual TasksModel requestNewInstance metadata.
The Quickshell integration includes a known unpinned running sentinel, last-window
removal, native typed New Window dispatch and actual KIO fallback for a closed
app while its normal startup reservation remains held. These tests do not raise
or minimize user windows. The existing settings_reload exception is unchanged.

## Minimize and pointer focus regression

DockFocusOwnership uses actual Qt pointer presses/releases to verify reveal and
repeated clicks never request native keyboard mode. It checks deliberate keyboard
entry/arrow/Enter, return to pointer mode, hide/reveal and menu mode. The native
activation tests still prove requestToggleMinimized on an eligible active window;
these are separate evidence levels, not physical KWin confirmation.
Use `qs ipc --path . call dock focusDock` for deliberate keyboard entry in a running
configuration. No new global shortcut or desktop setting is installed.

## Native icon-theme refresh

Explicit Kirigami icon surfaces attach `Punchi.Kde.IconThemeRefresh`. One native
Qt D-Bus receiver listens to KDE's `/KIconLoader`,
`org.kde.KIconLoader.iconChanged(int)` notification. The attached adapter queues
`QQuickItem::polish()` on the GUI thread after native notification handling.
KIconLoader retains responsibility for theme selection and cache invalidation;
Kirigami retains rendering, coloring, geometry and accessibility. Source names,
models and delegates remain intact. No polling or theme configuration writes
occur in the application.

The contract follows KIconLoader's notification/refresh implementation and
[the KDE platform theme](https://invent.kde.org/plasma/plasma-integration/-/blob/master/qt6/src/platformtheme/khintssettings.cpp).
Kirigami's existing icon connects palette updates to polish but does not subscribe
to icon-theme changes itself. This small bridge closes that notification gap.
It uses the existing KDE renderer rather than duplicating its icon lookup rules.

`icon_theme_runtime` renders six production surfaces under actual Quickshell and
KDE style, with two parent-owned SVG icon themes, isolated configuration and a
private bus without host auto-activation. It emits the same six icon-group
notifications as the Plasma icon KCM, checks center pixels across three live
changes, and preserves launcher source/scale/focus state. The test uses Python
Pillow for image inspection; Qt D-Bus is an explicit native build dependency.
Temporary themes, captured images, configuration and processes are cleaned up.
No user's theme is changed. Physical desktop switching remains a manual check.

## Lateral dock validation

`VerticalDock` covers pointer-driven vertical magnification, upright icons,
indicators below icons, Up/Down focus, scroll overflow, edge-clearance holding,
side-specific overlap rectangles, icon-anchored popups and a subsequent click
on a different launcher. Position changes exercise the real settings control
and preserve Apply, discard, external notifications and legacy defaults.
`autohide_edge` uses an owned Wayland server to verify left/right layer anchors
and KDE edge borders, pointer retention, edge rebuilds and bounded buffer sizes.

`vertical_dock_runtime` verifies composition and owned PunchiSettingsStore writes under
Quickshell with KDE style. Qt offscreen has no PanelWindow backend, so this test
uses an explicitly substituted FloatingWindow host in a temporary copy, with
typed edge/margin fields. Production content and wiring remain unchanged;
layer-shell placement is not tested by that substitution. The native edge
protocol is exercised separately. Window-mask warnings are platform limitations
and stay visible. Physical KWin placement, work-area coexistence, DPI and GPU
performance require manual validation. The registered settings_reload host probe
remains excluded under the current session-testing restriction.

## Screen and desktop placement validation

`PunchiScreenSelection.js` is pure JavaScript: `tst_screen_selection` covers modes,
primary fallback, reconnect and shared-edge geometry. `tst_screen_policy`
injects fake screens and a primary name into the real policy, so hot-plug and
selection reactivity run without a compositor. `tst_virtual_desktop_policy` uses
a fake `PunchiRunningApplications` object for desktop, activity, combined and
unavailable-backend cases. `tst_panel_policy` covers the internal-edge
suppression, and `tst_settings` covers the new profile fields and controls.

`placement_runtime` starts an offscreen Quickshell shell with fake screens, two
fake docks and `PunchiDockIpc`. It checks `screenKeys`, primary snapshot routing,
unknown-screen refusal, mode validation, selected-screen filtering, desktop
filtering and reconnect fallback. The fake documents stay in a temporary copy;
the production shell is not modified.

Native coverage: `window_models` asserts the `currentDesktopTasks` filters, and
`running_state` feeds `activities` and `currentDesktopIds` through the real
parser, including rejection of an application outside the running set.

Real session, 2026-10-27, Fedora 44, Plasma/KWin 6.7.5, eDP-1 + HDMI-A-1:
`screenKeys` returned both connectors; each dock reported its own 1920-wide
window and resting region. A temporary `PUNCHI_PROFILE_DIR` selected one screen,
a missing screen (primary fallback), an excluded current desktop, an excluded
activity and `dockEdge=right` with `autohide`. The excluded states reported
`windowAllowed: false`, `exclusiveZone: 0` and kept the shell alive; the allowed
reserve state reported 56. The dock on the internal right edge stayed `overlay`
while the outer edge kept `autohide`. Physical cable removal, other layouts,
fractional scaling and visual inspection remain manual. Spectacle fullscreen
capture omitted layer-shell surfaces in this session, so the check used IPC
state, not pixels.

## Owned KWin minimize-effect settings

The context menu may change only the KWin `Plugins/*Enabled` entries in the
`exclusiveGroup=minimize` effect group, and only after an explicit selection.
Before writing, Punchi Dock Quickshell atomically records the original key presence/value
and its own resulting values in the owner-only
`$XDG_STATE_HOME/punchi-dock-quickshell/owned-settings.json` file. Existing
records under `punchi-shell/` are read during migration and retained when a new
record already exists. Metadata files are
bounded to 1 MiB; the recovery document is bounded to 64 KiB. Repeated changes
retain the first snapshot. On clean shutdown, or by invoking
`punchi-window-state --restore-desktop-settings` from `restore-kde.sh`, the
controller restores only entries that still exactly match Punchi Dock Quickshell's last
write. It deletes keys that were originally absent and preserves current values
that no longer match. A failed save or restore keeps the recovery file for retry.
KWin receives an asynchronous `reconfigure` request after a successful change or
restoration. The isolated `kwin_minimize_effect` test covers config preservation,
clean and explicit recovery, external edits, private file permissions, bounded
metadata and KWin reconfiguration; real desktop behavior still needs a manual
session check.

## Settings About page

The settings sidebar provides an About page after Items and General. It reuses
the repository's SVG mark and README overview, displays the current application
version, and uses Kirigami URL buttons for the project repository and issue
tracker. `Read the license` opens a modal viewer with the verbatim GPL-3.0 text
read from the installed `LICENSE` by `PunchiLicenseDocument`; closing the viewer never
closes the settings window. Attribution follows `NOTICE.md`. `application_items`
verifies page navigation, displayed version, logo loading, the fixed external
destinations, and that the license viewer shows the bundled text and closes on
Escape without closing the settings window. This does not replace a visual check
under a real desktop theme.

## Icon theme scan cache

The icon chooser enumerates the active theme plus the themes it inherits, so the
settings dialog never depends on a hand-written icon list. Only that chain and
`hicolor` are read: the remaining installed themes are deliberately skipped,
because names are resolved through the active theme and a name from a foreign
theme would render as the missing-icon glyph. Installing more themes therefore
neither enlarges the list nor slows the scan.

`icon_theme_catalog` builds an owned theme in a temporary directory and checks
the native scan directly: the first run reports `cached == false`, the second
reuses the entry the first one wrote, and adding an icon file forces a rescan
with the new name. The cache lives under
`$XDG_CACHE_HOME/punchi-dock-quickshell` and is keyed by a fingerprint of each
`index.theme` and of every scanned directory's modification time and entry
count, so a theme update, a new directory or a removed asset each invalidate
it. Unreadable or damaged entries are ignored rather than trusted, and a
missing cache location leaves the picker unaffected.
On the observed theme (18 188 names, ten categories) the cold scan took about one
second and the cached load about thirteen milliseconds. The scan itself keeps
running on a worker thread, so the dialog opens while it completes. The same test
also checks that repeated Qt SVG warnings from an unparsable asset are folded into
one report per distinct message, that unrelated messages are never folded, and
that the suppression count is reported when the catalog is destroyed. Physical
rendering of a broken asset in a real session remains a manual check.

## Container entry selection

A folder container stores the entry names its popup must skip in the container
record itself, so the choice travels with the item and needs no separate store.
`hiddenNamesFilterTheListingWithoutHidingThemFromSettings` checks the native side:
hidden rows leave the model the popup reads, the settings list keeps every entry,
names that could leave the folder are refused instead of stored, a cleared list
shows everything again, and a name that no longer exists hides nothing else.
`test_containerSelectionKeepsEntriesOutOfThePopup` drives the real editor and the
details pane: nothing is listed before a folder is chosen, unchecking reaches the
stored container on Add, the details pane saves immediately, and **Show all**
clears the list. `test_popupSkipsEntriesTheOwnerKeptOut` opens the real popup and
confirms the filtered row disappears and returns once the list is cleared.

The settings listing is created lazily, only while it is on screen. It is backed
by `KDirLister`, and a KIO object kept alive in a hidden page would also outlive
the window that owns it; the popup keeps its own listing because it only exists
while the popup is open.
