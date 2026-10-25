# Window Factory icon

The owner selected **Pane arrangement** from three concepts on 2026-10-25.
The refined transparent raster concept is `pane-arrangement-concept.png`:
one tall window pane on the left, two stacked panes on the right, a cobalt base.
Generated with the built-in image-generation tool; it is a design asset, not
an installed app resource yet. The build does not package this Design directory.

Before shipping: review the refined form at Dock and 16/32 px sizes, clean the
outer alpha contour if necessary, prepare the complete macOS icon set and add
CFBundleIconFile to the bundle. Keep the existing bundle/signing identity so
icon changes do not invalidate Accessibility. The status-bar desktop badge
continues to show its number; it is independent of the app icon.


## Material variations — 2026-10-25

Three requested alternatives were generated with the built-in image tool, using
`pane-arrangement-concept.png` as the edit reference. These remain design
explorations; no installed icon, app build, controls or Hammerspoon files changed.

| Asset | Direction |
| --- | --- |
| `pane-outline-concept.png` | Bright icy outlines, unfilled pane interiors showing the cobalt base |
| `pane-glass-concept.png` | Translucent cyan glass, refractive edges and transmitted blue tones |
| `pane-sculpted-concept.png` | Surprise: recessed monochromatic blue architectural wells |

Prompt set: preserve the centered frontal cobalt rounded-square base and exact
one-tall-left/two-stacked-right arrangement, with equal margins/gaps and no text,
chrome, extra panes or rotation; transparent outside the base. Outline variant:
continuous substantial white/icy-blue rounded outlines, empty interiors, minimal
edge highlights. Glass variant: true optical transmission, restrained thin-glass
bevels, cyan tint, controlled reflections and a tonal wave demonstrating refraction.
Sculpted variant: carved negative-space cavities, softened inner bevels, deep
indigo interiors and electric-blue rim lighting, with no white-filled panes.

The generated alpha contours still need production cleanup before packaging.
Material and small-size legibility selection should precede that work.
