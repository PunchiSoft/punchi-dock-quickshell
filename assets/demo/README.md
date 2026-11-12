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

## `menu-overview.webp`

The fullscreen menu opening over the desktop and scrolling through application
rows, recorded on 2026-11-11 (`plasmashell 6.8.2`, `kwin 6.8.2`, Qt 6.11.2,
Quickshell 0.2.1 on Wayland from Fedora 44). The dock keeps its maintainer's
launcher set, so the icons are not the first-run defaults.

The source recording is a 1920x1080 capture of 40 s and 24 MB. Only the opening
and the first scroll are published: `menu-overview.webp` is 960x540, 63 frames and
6.6 s at 10 fps, 1.7 MB. The desktop-idle seconds at the start and the empty
desktop after the menu closes are not part of the clip. Scaling the whole 1080p
frame to 854x480 makes the application labels unreadable, and 960 px is the width
the README displays, so the asset keeps that width instead of a full-height scale.
It was rebuilt from the source animation with Pillow, which reads one frame at a
time and never holds the whole recording in memory:

```bash
python3 - <<'EOF'
from PIL import Image
source = Image.open('recording.webp')
fps = source.n_frames / 40.0
frames = []
for index in range(int(4.4 * fps), int(10.4 * fps)):
    source.seek(index)
    frames.append(source.convert('RGB').resize((960, 540), Image.BILINEAR)
                  .convert('P', palette=Image.ADAPTIVE, colors=255))
frames[0].save('assets/demo/menu-overview.webp', save_all=True,
               append_images=frames[1:], duration=100, loop=0,
               quality=76, method=6)
EOF
```

Pillow merges identical consecutive frames and keeps their delay, so the frame
count differs from the sampled range while the 6.6 s duration is preserved. Keep
this asset well under 10 MB; a 24 MB clip belongs outside the repository, because
a public clone downloads every version of it forever.
