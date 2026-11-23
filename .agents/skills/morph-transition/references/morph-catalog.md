# Morph pattern catalogue

Detail for `morph-transition`. Patterns are ordered by cost; use the first one
that keeps the spatial relation. All mechanisms are expressed for Qt Quick, not
copied from the web or from another shell.

## Patterns

| Pattern | Use when | Mechanism | Cost | Failure it prevents |
|---|---|---|---|---|
| Container transform | Origin and target are the same object or the same context, and only bounds and radius change. | One childless surface interpolates rect and radius from the origin to the target; content is at final size and fades in after the start. | LOW/MEDIUM | Scale-from-center, content squash, lost origin. |
| Clip reveal with axis stagger | The surface should look poured out of the control that opened it, and both axes change differently. | An animated clip of the surface silhouette runs from the origin rect and radius to the target; width leads and height follows; the content is at final size and never reflows. | LOW/MEDIUM | Layout animation, abrupt size change. |
| Path morph | The silhouette itself changes: capsule to panel, tail emerging, corner radius opening unevenly. | One `Shape` with a fixed segment list; control points derive from the progress. | MEDIUM | Geometry jump between two unrelated shapes. |
| SDF fusion | Two or more shapes should connect with a neck while one moves: dock and surface, lobe and lobe. | Rounded-rect or capsule SDFs combined with a smooth minimum; anti-aliasing from screen derivatives; opaque fill; one `MultiEffect` for shadow. | HIGH | Disconnected silhouettes, aliasing, per-frame blur. |
| Fade-through | There is no shared object or context, only a change of content. | Outgoing content fades out; incoming content fades in and settles from `scale 0.97`. | LOW | A false promise of spatial continuity. |

## Timing starting points

- One progress owns the whole transition; do not chain separate geometry
  animations.
- Surface bounds: `longDuration`, scaled only if the distance requires it.
- Outgoing content: the first third at most.
- Incoming content: the last two thirds.
- Closing: the same geometry in reverse, on a shorter scaled duration.
- Arc travel is for a surface that crosses the screen. A local expansion does not
  need it; adding it makes the result feel theatrical and costs distance.

## Implementation map

- Progress: one real property plus a `Behavior`, so reversal retargets instead of
  restarting.
- Origin data: rect and corner radius of the control, captured before the surface
  is created. Capture both; a rect alone cannot reproduce the origin shape.
- Silhouette: prefer a childless surface at the animated geometry. Reach for
  `Shape` only when the silhouette changes shape, and for `ShaderEffect` only
  when shapes must fuse.
- Content: final geometry from the first frame; reveal with opacity and a small
  offset; never with `width`, `height` or text scaling.
- Shadow: one effect for the whole silhouette, not one per animated part.

## Anti-patterns

- Presenting a center scale and a cross-fade as a morph.
- Morphing between surfaces that do not share an object or a context.
- Animating the content's layout to follow the surface.
- Clipping a full-size content subtree to fake a container transform.
- Rebuilding the path element list or path strings on every frame.
- Introducing an SDF shader when a rounded rectangle already keeps the relation.
- Locking input until the morph finishes.
- Adding a spring "for feel" to a navigation transition.

## Open decisions

- Curve token: `PunchiMotion.move` is the current default for on-screen morphing.
  If a surface needs a slower start and a longer settle, decide an emphasized
  token once, next to the code, instead of writing a bezier inline.
- Origin radius: expose it with the origin rect, or derive it from the control's
  shape; do not guess a fixed radius.
- Fallback: when the silhouette cannot be drawn (software backend, no shader, or
  reduced motion), the final geometry must remain legible without the effect.

## Sources

- Material Design 3 transition patterns:
  <https://m3.material.io/styles/motion/transitions/transition-patterns>
- `container-transform` in soilmass/motion-design-agent (MIT License, Copyright
  (c) 2025 edox1):
  <https://github.com/soilmass/motion-design-agent>
- LiquidMorph in the `fluid_glass` package (Apache-2.0):
  <https://pub.dev/documentation/fluid_glass/latest/fluid_glass/LiquidMorph-class.html>
- Quickshell SDF morph field by StatIndet (GPL-3.0):
  <https://github.com/StatIndet/quickshell>
- Qt Quick `Shape` (path properties are animable; CPU retessellation):
  <https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html>
- Inigo Quilez, smooth minimum:
  <https://iquilezles.org/articles/smin/>
