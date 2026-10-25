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
