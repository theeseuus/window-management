# Unified Workspaces panel: design QA

Reviewed 2026-10-07 in Hammerspoon 1.1.1 on macOS.

## Visual truth and comparison

The selected design combines the flat layout list, horizontal title/search
header, and labelled bottom action bar. Capture, naming, and confirmations use
that same window. The owner's subsequent copy decision takes precedence over
the capture mockup: show the captured count, not “Positions are frozen…” or
“Snapshot ready”. Functional previews must depict saved recipe geometry rather
than hard-coded artwork.

| State | Source visual truth | Rendered implementation |
| --- | --- | --- |
| Library, Claude selected, three recipes | `docs/design/workspaces-library-reference.png` | `docs/design/workspaces-library-native.png` |
| Capture ready, five windows, Project Workspace entered | `docs/design/workspaces-capture-reference.png` | `docs/design/workspaces-capture-native.png` |
| Narrower library | No separate source mockup; same design contract | `docs/design/workspaces-library-narrow.png` |

The source images are panel crops of the approved generated mockups. Their
original canvases are 1448 × 1086 pixels; the library panel crop is 1104 × 767,
and capture is 1104 × 791. Both were normalized proportionally to 660 pixels
wide, giving 660 × 459 and 660 × 473. The native captures are 660 × 520 pixels
at 1 pixel per window point, with a 660 × 488 CSS content viewport and 32 points
of actual AppKit title-bar chrome. The narrower capture is 540 × 520, with
540 × 488 content. The theme is dark. No full-desktop screenshot or window
content is included.

The source and implementation images were opened together in the same
comparison input for both main states. Comparison used equal-width, 1× panel
images and corresponding content regions; the native title bar, source canvas
padding, and approved copy removal were not treated as visual defects. The
native window is slightly taller to retain its real title bar and keep the
capture form and persistent action bar visible together. It does not simulate
macOS window controls inside HTML.

The complete 660-pixel views make the heading, search, row hierarchy, outline
geometry, focused name field, privacy copy, buttons, and captions readable.
Additional focused crops were not necessary. The native 540-pixel view was
also inspected for header, row, and footer overlap.

## Findings and comparison history

No actionable P0, P1, or P2 findings remain.

1. Initial native capture observation: a small vertical overflow appeared in
   the five-window capture state. **P2**, capture spacing. Reduced capture
   padding and maximum preview height. The revised capture image above shows
   the complete form and privacy note without an unnecessary scrollbar;
   Cancel and Save remain fixed below it.
2. Initial Save interaction: a fourth recipe was selected below the visible
   list. **P2**, saved-selection visibility. Explicit selected names now scroll
   into view. Repeating native Save showed the new row fully visible and
   selected, with the header and footer still fixed. Scrolling a longer library
   is intentional; the default three-recipe image has no content overflow.
3. Library preview/text spacing was adjusted from a 130-point thumbnail and
   18-point gap to a 145-point thumbnail and 20-point gap. The revised library
   image was compared against the source again; outline and text alignment
   now follow the selected composition. The 540-point view uses smaller
   thumbnails and retains readable, separate app summaries.

An initial saved screenshot was captured before WebKit finished drawing and
was blank. It was discarded as evidence, not treated as a rendered result.
The evidence above was captured after drawing and visually opened. A native
diagnostic also revealed that Hammerspoon can supply `{ code = 0 }` instead
of nil on successful JavaScript evaluation; the wrapper now recognizes that
success and clears stale diagnostics. Regression tests cover both success and
genuine native error descriptions.

## Required fidelity surfaces

- **Fonts and typography:** WebKit reports the system stack
  `-apple-system, BlinkMacSystemFont, sans-serif`. Titles, counts, and app names
  have distinct lines and weights, without timestamps or combined instructions.
  The 14-point base, 17-point row titles, and smaller footer captions use native
  interface hierarchy. Search and naming fields are labelled and keyboard
  accessible. Long names/app summaries wrap rather than injecting HTML.
- **Spacing and layout rhythm:** one 660-point-wide window, a horizontal
  library header, flat rows with larger outline thumbnails, and a persistent
  bottom action bar. Native window corners and title-bar controls come from
  AppKit. Three saved rows fit; larger libraries scroll only in the main area.
  The capture-ready form fits after the spacing correction.
- **Colors and visual tokens:** dark neutral surface, readable muted text,
  system-blue selection/focus/primary actions, and red only for destructive
  confirmation. Light-theme tokens follow the system media query without
  changing macOS preferences. The macOS screen-capture indicator visible in
  native images is platform chrome, not part of the panel.
- **Image quality and assets:** no decorative bitmap assets at runtime.
  Search and trash use AppKit template images. Layout outlines are functional,
  deterministic vector geometry explicitly requested by the owner; they are
  not substitutes for photographs, logos, or hard-coded recipe artwork. Each
  stored rectangle, including overlaps and unused areas, contributes to the
  preview. Existing recipes require no migration.
- **Copy and content:** Restore says “Arrange existing windows”; Establish
  says “Open missing apps and windows”. Capture ready says “5 windows captured”
  and retains the privacy note. Delete and replace name the exact target and
  describe what changes. Save returns to the library with its new recipe
  visible. Cancel returns without writing.

## Interaction and safety checks

Native UI pilot checks used an in-memory catalog, synthetic capture records,
and print-only placement receipts from `tests/manual_panel_pilot.lua`:

- search by layout name; selected recipe follows the filtered result;
- Return dispatches Restore, Command + Return dispatches Establish, then closes
  the panel without moving real windows;
- Capture reuses the same native window; naming and Save enable after readiness;
- naming enables Save, Return saves, and the new selected row is visible;
- right-click exposes Restore, Establish, and Delete; Escape dismisses the menu
  without closing the library;
- Command + Delete opens inline confirmation with Cancel focused; ordinary
  Return cancels; explicit Delete removes only the memory-only target;
- replacement requires confirmation; cancellation preserves the typed name
  and frozen preview; confirmed replacement refreshes the application summary;
- Escape from capture returns to the library; Escape from the library closes;
- native 540-point width keeps search, Capture, rows, and persistent actions
  visible; native JavaScript reports no default-library content overflow.
- an empty native library shows a Capture prompt and disables Restore,
  Establish, and Delete while leaving the same window open.

Persisted recipes were compared with their pre-pilot value and were unchanged.
The automated suite separately covers frozen frames, capture failure, catalog
errors, stale events, changed confirmation targets, destination retention,
full-screen rejection, stop/close cleanup, and the original placement engines.

## Remaining coverage and follow-up polish

- Actual Restore/Establish window movement was not repeated in the visual
  pilot, to avoid rearranging the owner's project windows. Their existing
  placement/creation engines are unchanged; regression tests and the manual
  integration checklist distinguish dispatch from live macOS placement.
- System light appearance, VoiceOver, very long catalogs, and monitor switching
  still warrant owner-side acceptance testing. Light tokens and accessibility
  labels are implemented; no system settings were changed to force testing.
- **P3:** native AppKit title-bar presentation and background translucency
  differ slightly from generated artwork. The window uses actual native
  chrome and a translucent local surface; no fake traffic lights or an
  unsupported vibrancy effect were added.

## Implementation checklist

- [x] Compare both selected mockup states against native rendered evidence.
- [x] Fix capture overflow and newly saved selection visibility, then recapture.
- [x] Inspect typography, spacing, color, geometry assets, and approved copy.
- [x] Exercise primary native interactions without changing saved owner data.
- [x] Check narrower-window controls and record remaining integration boundaries.

final result: passed
