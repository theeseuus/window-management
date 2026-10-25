# Window Factory icon

The installed icon is **Sculpted blue**, chosen after the pane-arrangement and
material explorations below. Build 47 packages `../WindowFactory.png` into a
standard macOS ICNS and sets `CFBundleIconFile` to `WindowFactory`.

The owner explicitly approved precise local transparency cleanup on 2026-10-25
after the image tool retained stray external pixels. `../../scripts/clean-icon.swift`
uses the original `pane-sculpted-concept.png`, trims only the outer contour with
an antialiased squircle mask and independently decodes the saved PNG to verify
clear exterior alpha and unchanged opaque interior pixels. The original remains
untouched. Regeneration uses the installed Apple Swift/ImageIO/CoreGraphics tools.

`../../scripts/package-icon.sh` generates the ten conventional 1x/2x PNG
representations (16, 32, 128, 256, 512 point sizes, up to 1024 physical pixels) and
uses Apple's `iconutil` to build the ICNS. Generated iconsets/ICNS live in the build
cache; only the approved master PNG and reproducible scripts are source assets.
The build does not package the Design directory or discarded concepts.

The bundle/signing identity remains unchanged to preserve Accessibility access.
The status-bar desktop-number badge is independent of the app icon. The installed
icon was checked through macOS's resolved app icon after refreshing Launch
Services registration; macOS adds its surrounding plate in that resolved view.

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

These concepts preserve the exploration history. The selected sculpted variant
was subsequently reviewed at 16–192px on light/dark backgrounds and cleaned for
production as described above.
