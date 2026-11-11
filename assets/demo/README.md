# Demo assets

Recorded dock behavior used by the public README. The recording shows this
repository running in a real KDE Plasma Wayland session; it is a record of the
recorded environment, not a compatibility claim for another one.

## `dock-magnification.webp`

Animated dock magnification with the pointer moving along the icons, recorded on
2026-11-11 (`plasmashell 6.8.2`, `kwin 6.8.2`, Qt 6.11.2, KDE Frameworks 6.31.0,
Wayland, Quickshell 0.2.1 from Fedora 44). The dock uses the maintainer's
launcher set, so the icons are not the first-run defaults.

The desktop capture is 982x261 and already excludes the screen recorder's
notification; the dock is visible from the first frame to the last, so the clip
needs no trim. `dock-magnification.webp` is downscaled and re-encoded to 960x255,
177 frames, 4.76 s and 1.3 MB. To rebuild it from the source recording, with the
same tools (ImageMagick):

```bash
magick recording.webp -coalesce \
  -resize 960x \
  -layers Optimize -quality 75 \
  assets/demo/dock-magnification.webp
```

If a future recording includes the recorder's notification, a hidden dock at
either end or a wider desktop area, measure the crop and frame range first and
add `-crop`/`-delete` as the previous recording did. The crop is what removes the
notification, so a wider crop publishes it. Keep the file well under 10 MB,
because GitHub does not render a larger image, and prefer animated WebP: the same
clip as a GIF is several times heavier. `-coalesce` preserves the recorded frame
delays, so the motion plays at the captured speed.
