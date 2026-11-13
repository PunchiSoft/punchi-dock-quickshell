# Demo assets

Recorded dock behavior used by the public README. The recordings show this
repository running in a real KDE Plasma Wayland session; they are a record of the
recorded environment, not a compatibility claim for another one.

## 2026-11-11 recording

The dock wave and the container clip come from one 1920x1080, 60 fps VP9
recording of 92 s and 7.1 MB, captured on 2026-11-11 with Spectacle 6.8.2
(`plasmashell 6.8.2`, `kwin 6.8.2`, Qt 6.11.2, KDE Frameworks 6.31.0,
Quickshell 0.2.1 on Wayland from Fedora 44). The recording walks through the dock
wave, a launcher context menu, a folder container, the settings window and the
fullscreen menu. Each published clip keeps one of those states; the idle desktop
between them is not published.

The dock wave was encoded straight from the WebM with ffmpeg's `libwebp_anim`,
one pass without holding the animation in memory:

```bash
# Dock wave: pointer sweep along the icons, cropped to the dock and its tooltips.
ffmpeg -ss 0.5 -to 6.8 -i recording.webm \
  -vf "fps=20,crop=900:240:510:840,scale=960:256:flags=lanczos" \
  -c:v libwebp_anim -lossless 0 -q:v 76 -compression_level 5 -loop 0 -an \
  assets/demo/dock-magnification.webp
```

## 2026-11-13 recording

A second 1920x1080, 60 fps VP9 recording of 38.3 s and 4.4 MB was captured on
2026-11-13 in the same Fedora 44 / Plasma 6.8.2 / KWin 6.8.2 / Qt 6.11.2 /
KDE Frameworks 6.31.0 / Quickshell 0.2.1 Wayland session. It provides the updated
fullscreen menu and the PunchiMenu dock-icon balloon. The `menu-overview` clip was
re-encoded from this take; the old 2026-11-11 menu take is no longer published.

```bash
# Updated fullscreen menu: opening and scrolling the corrected grid.
ffmpeg -ss 5.5 -to 13.5 -i recording-2026-11-13.webm \
  -vf "fps=12,scale=960:540:flags=lanczos" \
  -c:v libwebp_anim -lossless 0 -q:v 74 -compression_level 5 -loop 0 -an \
  assets/demo/menu-overview.webp

# PunchiMenu dock-icon balloon: the app list, a scrolled pointer and the actions.
ffmpeg -ss 18.5 -to 26.5 -i recording-2026-11-13.webm \
  -vf "fps=12,crop=720:1000:420:80" \
  -c:v libwebp_anim -lossless 0 -q:v 74 -compression_level 5 -loop 0 -an \
  assets/demo/punchimenu-context.webp
```

Keep the source recording outside the repository: a 7 MB WebM or a 24 MB capture
would be downloaded by every clone forever. Publish only the encoded WebP, keep
each clip between roughly 0.3 and 2 MB, and prefer animated WebP over GIF, which
is several times heavier for the same motion. GitHub does not render an image
above 10 MB.

Do not scale a full 1080p frame to 854x480: it saves almost nothing and makes the
application labels unreadable. Use 960 px wide, which is what the README
displays, and crop to the surface the clip is about.

## `dock-magnification.webp`

The pointer moving along the dock, with the neighbouring icons enlarging and the
tooltips following it. 960x256, 100 frames, 6.3 s at 20 fps, 0.41 MB. The crop is
the dock strip plus the space its tooltips and enlargement need, so the recorder's
tray indicator is outside the frame. The dock uses the maintainer's launcher set,
so the icons are not the first-run defaults.

## `menu-overview.webp`

The corrected fullscreen menu opening from the dock and scrolling through the
application rows. 960x540, 92 frames, 7.7 s at 12 fps, 1.37 MB. Re-encoded from
the 2026-11-13 recording; the application set is the maintainer's.

## `punchimenu-context.webp`

The balloon opened by right-clicking the leading PunchiMenu dock icon: the
installed applications sorted by name, then **Remove from Dock**, **Show
PunchiMenu** and **Configure PunchiDock**. 720x1000, 90 frames, 7.5 s at 12 fps,
0.88 MB. The recording scrolls the application list while the pointer is over the
balloon. The crop keeps the balloon and the left dock; the application set is the
maintainer's.

## `container-views.webp`

The Home container changing presentation: **Detail** with its check mark in the
**View content as** menu, then **Grid**, then **Fan**. A continuous 15.6 s take
from the 2026-11-11 recording, 960x686, 139 frames at 10 fps, 0.64 MB, cropped to
the balloon and the dock it hangs from.

`List` does not appear for a folder container in this recording; the only list
shown is the recent-applications container. Re-record that step before claiming
all four presentations in one clip.

```bash
ffmpeg -ss 13.0 -to 28.6 -i recording.webm \
  -vf "fps=10,crop=980:700:540:330,scale=960:-1:flags=lanczos" \
  -c:v libwebp_anim -lossless 0 -q:v 74 -compression_level 5 -loop 0 -an \
  assets/demo/container-views.webp
```

The crop is the union of every state in the take, so the balloon never leaves the
frame while it moves between its Grid, Fan and menu positions.
