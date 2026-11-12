# Demo assets

Recorded dock behavior used by the public README. The recording shows this
repository running in a real KDE Plasma Wayland session; it is a record of the
recorded environment, not a compatibility claim for another one.

## Shared recording

Both clips come from one 1920x1080, 60 fps VP9 recording of 92 s and 7.1 MB,
captured on 2026-11-11 with Spectacle 6.8.2 (`plasmashell 6.8.2`, `kwin 6.8.2`,
Qt 6.11.2, KDE Frameworks 6.31.0, Quickshell 0.2.1 on Wayland from Fedora 44).
The recording walks through the dock wave, a launcher context menu, a folder
container, the settings window and the fullscreen menu. Each published clip keeps
one of those states; the idle desktop between them is not published.

Both were encoded straight from the WebM with ffmpeg's `libwebp_anim`, one pass
without holding the animation in memory:

```bash
# Dock wave: pointer sweep along the icons, cropped to the dock and its tooltips.
ffmpeg -ss 0.5 -to 6.8 -i recording.webm \
  -vf "fps=20,crop=900:240:510:840,scale=960:256:flags=lanczos" \
  -c:v libwebp_anim -lossless 0 -q:v 76 -compression_level 5 -loop 0 -an \
  assets/demo/dock-magnification.webp

# Fullscreen menu: opening and scrolling the application rows.
ffmpeg -ss 82.5 -to 90.5 -i recording.webm \
  -vf "fps=12,scale=960:540:flags=lanczos" \
  -c:v libwebp_anim -lossless 0 -q:v 74 -compression_level 5 -loop 0 -an \
  assets/demo/menu-overview.webp
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

The fullscreen menu opening from the dock and scrolling through the application
rows. 960x540, 94 frames, 8 s at 12 fps, 1.9 MB. The application set is the
maintainer's.
