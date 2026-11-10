# Demo assets

Recorded dock behavior used by the public README. The recordings show this
repository running in a real KDE Plasma Wayland session; they are records of the
validated environment, not a compatibility claim for another one.

## `dock-magnification.webp`

Animated dock magnification with the pointer moving along the icons, recorded on
2026-11-10 (`plasmashell 6.8.2`, `kwin 6.8.2`, Wayland, Quickshell 0.2.1 from
Fedora 44). The dock uses the default launchers.

The desktop capture is not published as recorded: it includes the screen
recorder's notification in the corner, begins and ends with the dock hidden, and
weighs several megabytes per second. `dock-magnification.webp` is cropped to the
dock strip, trimmed to the span where the dock is fully visible, downscaled and
re-encoded to 960x233, 285 frames, 8.1 s and 2.5 MB. To rebuild it from a
recording, with the same tools (ImageMagick):

```bash
magick recording.webp -coalesce \
  -delete 0-28,315-330 \
  -crop 1160x282+380+0 +repage \
  -resize 960x \
  -layers Optimize -quality 75 \
  assets/demo/dock-magnification.webp
```

The frame numbers and crop offsets belong to that 1920x282 capture; measure them
again for another recording and keep windows, the pointer notification and any
other surface you do not mean to publish out of the frame. The crop is what
removes the recorder's notification, so a wider crop publishes it. Keep the file
well under 10 MB, because GitHub does not render a larger image, and prefer
animated WebP: the same clip as a GIF is several times heavier. `-coalesce`
preserves the recorded frame delays, so the motion plays at the captured speed.
