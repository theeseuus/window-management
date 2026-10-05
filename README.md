# Theseus Window and Workspace Management

This repository contains two independent Hammerspoon Spoons:

- **TheseusWindow** provides deterministic macOS window placement, window
  switching, and native Space movement.
- **TheseusWorkspace** captures and restores named, cross-application window
  layouts in the current native user Space.

Either Spoon can be installed and loaded without the other. The reference
configuration keeps broader responsibilities separate:

- Karabiner defines key semantics. Holding Tab emits Hyper
  (`Control + Option + Command`).
- Raycast launches applications.
- Hammerspoon and these Spoons manipulate windows.
- Native macOS `Control + Left/Right` moves only the user between Spaces.

The complete reference map is in [SHORTCUTS.md](SHORTCUTS.md). Its application
launch shortcuts document one example setup and are not implemented by this
Spoon.

## Requirements

- For TheseusWindow move-and-follow, macOS with native Mission Control
  `Control + Left/Right` shortcuts enabled.
- Hammerspoon with Accessibility permission; version 1.1.1 is the tested
  release.
- At least two ordinary user Spaces for TheseusWindow move-and-follow commands.
- An ordinary user Space for TheseusWorkspace capture and restore. Full-screen
  and tiled Spaces are deliberately rejected.
- A Hyper-key mapping if using the reference bindings. The supplied setup uses
  Karabiner-Elements to make held Tab emit
  `Control + Option + Command`; Karabiner configuration is not included.

## Installation

1. Copy either or both Spoon directories into `~/.hammerspoon/Spoons/`:

   - `Hammerspoon/TheseusWindow.spoon`
   - `Hammerspoon/TheseusWorkspace.spoon`

2. Merge the following lines into your existing `~/.hammerspoon/init.lua`;
   do not overwrite unrelated Hammerspoon configuration:

   ```lua
   hs.loadSpoon("TheseusWindow")
   spoon.TheseusWindow.showSpaceIndicator = true
   spoon.TheseusWindow:bindHotkeys():start()

   hs.loadSpoon("TheseusWorkspace")
   spoon.TheseusWorkspace:bindHotkeys({
     capture = { { "ctrl", "alt", "cmd", "shift" }, "r" },
     restore = { { "ctrl", "alt", "cmd" }, "r" },
   }):start()
   ```

   Remove either block when that Spoon is not wanted. TheseusWorkspace does not
   load or call TheseusWindow internally. The two Workspace bindings shown here
   are the supplied reference map, not hard-coded defaults.

3. Reload Hammerspoon and grant Accessibility access if macOS requests it.
4. Work through the manual integration checklist below before relying on live
   window or Space operations.

If dotfiles are managed by chezmoi or another configuration manager, add these
files to its source state and deploy them through that manager.

## TheseusWindow

TheseusWindow provides cross-app window switching, deterministic geometry
cycles in both directions, stateless canonical size and position cycles,
current-Space directional focus, stash/restore, accordion layout, a centred
half-width layout, position-preserving horizontal centering, maximize/minimize,
geometry restoration, width adjustments, and spatial arrow controls.

## TheseusWorkspace

TheseusWorkspace treats the eligible windows in the current native user Space
as one cross-application project group. Its initial capture-and-reconcile slice
supports:

- `Hyper + Shift + R`: open the capture dialog immediately, freeze the current
  workspace, then name and save that snapshot. Naming and Save stay disabled
  while capture is in progress. An existing name requires explicit replacement
  confirmation.
- `Hyper + R`: choose a saved workspace and restore its matching existing
  windows in the current Space.
- Named recipe listing and explicit deletion through the public Spoon API.
- Normalized geometry, so a recipe is restored relative to the current screen's
  usable frame rather than an old absolute pixel rectangle.
- Missing-window and extra-window reporting. Missing recipe slots are reported;
  extra windows are intentionally left untouched.
- Verified placement: wait for each frame to settle before counting it as
  placed, retry a quiet no-op, then try a separated resize/move if necessary.
  A request that still does not reach its saved frame is reported as failed,
  with the application named in the completion notice.

Capture includes normal, visible, non-minimized, non-full-screen windows that
belong exclusively to the current ordinary user Space and selected screen.
Sticky windows, panels, desktop elements, hidden/minimized windows, full-screen
windows, and windows on another screen are skipped. The current implementation
is intentionally single-monitor-first.

The dialog first shows **Capturing…**. Keep windows still until it shows
**Snapshot ready** and enables the name field. You can then rearrange windows,
switch Spaces, or take your time naming the layout: Save uses only the frozen
snapshot, never another read of the live windows. Cancel, Escape, or closing the
dialog discards the unsaved snapshot. Repeating the capture shortcut brings the
existing dialog forward rather than starting another capture.

Window discovery uses one application-window enumeration per operation instead
of a full scan for every window ID. Capture still reads macOS Accessibility
information sequentially; it is not an atomic screenshot of the entire desktop
at the instant the key is pressed. If the selected Space changes during
collection, capture fails without saving. The capture dialog itself is excluded.

Recipes identify a slot using the owning application's bundle identifier plus
an ordinal. They do not store window titles, document paths, browser URLs,
terminal working directories, or window contents. When an application has
several windows, existing windows are paired with its saved slots by proximity
to the normalized saved geometry. This preserves sensible placement without
claiming that Hammerspoon can recover the original document or tab identity.

The first slice reconciles only windows that already exist in the destination
Space. It does **not yet** launch applications, create missing blank windows,
move a group between Spaces, create or remove Spaces, or continuously enforce a
layout. Those capabilities require app adapters and a separately verified group
transport state machine.

Recipes are stored under the Hammerspoon settings key
`TheseusWorkspaceRecipesV1`, outside this Git repository. The public API can
also be used directly from the Hammerspoon Console:

```lua
spoon.TheseusWorkspace:captureCurrentWorkspace("Project Atlas")
spoon.TheseusWorkspace:captureCurrentWorkspace("Project Atlas", { replace = true })
spoon.TheseusWorkspace:restoreWorkspace("Project Atlas")
spoon.TheseusWorkspace:listWorkspaces()
spoon.TheseusWorkspace:deleteWorkspace("Project Atlas")
```

The direct `captureCurrentWorkspace` API captures and saves synchronously when
called; the shortcut uses the non-blocking capture/name/save dialog. Both store
the same recipe schema, so existing recipes remain compatible.

Restoration is asynchronous. The returned report has `finished` and `pending`
fields; it remains unfinished while frame checks are pending. Its `applied`
count includes only frames verified within two screen points of the target.
Use `onComplete` when consuming the result:

```lua
spoon.TheseusWorkspace:restoreWorkspace("Project Atlas", {
  onComplete = function(report)
    print(report.applied, #report.missing, #report.failures)
  end,
})
```

The latest completed report is also available as
`spoon.TheseusWorkspace.lastRestoreReport` until Hammerspoon reloads. Its
`failures` entries include an application slot and a reason such as
`frame-not-restored`. These diagnostic reports are not persisted with recipes.
An overlapping restore is rejected, and retries stop if the window becomes
ineligible, the active Space changes, or the Spoon stops. Placement does not
activate applications or steal focus.

`excludedBundleIDs` can omit an application from capture and restore matching:

```lua
spoon.TheseusWorkspace.excludedBundleIDs = {
  ["com.example.Utility"] = true,
}
```

## Directional window focus

- `Hyper + H`: focus the closest suitable window to the left.
- `Hyper + J`: focus the closest suitable window below.
- `Hyper + K`: focus the closest suitable window above.
- `Hyper + L`: focus the closest suitable window to the right.

Candidates are limited to normal, visible, non-full-screen windows in the
current Space. The focused window's current screen gets first refusal before
the command considers another visible screen in that Space. Left/right
selection requires positive vertical overlap; up/down requires positive
horizontal overlap. This keeps focus in the same visual row or column instead
of allowing a diagonally placed window to win. No window geometry changes.

The example Raycast map in `SHORTCUTS.md` also lists `Hyper + K` for Shortcut
Viewer. TheseusWindow reserves that binding for upward focus, so remove or
reassign the Raycast binding if it remains configured.

## Stateless canonical geometry

- `Hyper + -`: cycle size through `1/2` → `1/4` → `1/8` → `1/16` → `1/2`.
- `Hyper + Shift + -`: run the same size cycle in reverse.
- `Hyper + =`: advance to the next canonical position for the current size.
- `Hyper + Shift + =`: move to the preceding canonical position.

These commands derive their result from the focused window's current frame;
they do not keep a hidden per-window cycle counter. A manually sized or placed
window is first interpreted as the nearest canonical size and position.
Changing size selects the target slot nearest the window's current centre.
When two finer slots are equally close, ties favour the outer edge already
occupied by the source window—for example, a top-right quarter becomes the
top-right eighth rather than its inward neighbour.

Canonical position order is:

- `1/2`: left → centre → right.
- `1/4`: top-left → top-right → bottom-right → bottom-left.
- `1/8`: top row left-to-right, then bottom row right-to-left.
- `1/16`: a four-row serpentine, alternating direction on every row.

The established `Hyper + 2/3/4/8` geometry cycles remain available for
comparison. Maximize, arrow controls, stash, accordion, Space movement, and the
cross-app switcher are unchanged.

## Spatial arrow controls

- `Hyper + Left`: move the focused window to the previous native user Space,
  follow it, and refocus that exact window.
- `Hyper + Right`: move the focused window to the next native user Space,
  follow it, and refocus that exact window.
- `Hyper + Up`: save the current frame, then use the existing centred
  half-width/full-height layout.
- `Hyper + Down`: restore the saved frame, or use the existing centred fallback
  when no frame has been saved.

The semantic distinction is deliberate:

- `Control + Left/Right` → move me between Spaces.
- `Hyper + Left/Right` → move this window and me between Spaces.

The move-and-follow command is a bounded state machine:

1. Require one focused, visible, standard, non-minimized, non-full-screen
   window.
2. Read its screen, the active Space, and that window's Space membership.
3. Read the screen's ordered Spaces, retain only `user` Spaces, and select the
   adjacent entry without wrapping.
4. Hold the window by a point beside its green title-bar button.
5. Release the triggering Hyper modifiers in the synthetic event stream and
   emit native `Control + Left/Right` as separate modifier/key down/up events.
   macOS then carries the held window through its normal Space transition.
6. Release the window and restore the pointer.
7. Poll until both the exact window's Space membership and the active Space
   match the selected destination.
8. Reapply the saved frame and retry focus until the exact window ID is focused.

Each wait has a timeout, concurrent move commands are rejected, and a
Hammerspoon alert identifies the failed stage. The code never creates or
removes a Space. The native-input mechanism is isolated in
`native_space_move.lua`; ordered selection and post-operation verification stay
in the main Spoon.

This transport was selected after live diagnosis on macOS 27.0 with
Hammerspoon 1.1.1. In that environment,
`hs.spaces.moveWindowToSpace` returned `true` without moving the window, while
`hs.spaces.gotoSpace` failed because the Dock no longer exposed the Mission
Control display group it expected. A complete native Control-arrow event
sequence worked, and holding the title bar during that transition moved the
window and user together.

## Width controls

- `Hyper + [` narrows the focused window.
- `Hyper + ]` widens the focused window.

Each press changes width by `80` points around the current horizontal centre.
The x-position is clamped to the current screen's usable frame. Height and
vertical position are unchanged.

The defaults can be changed before `bindHotkeys()`:

```lua
spoon.TheseusWindow.widthStep = 80
spoon.TheseusWindow.minWindowWidth = 360
spoon.TheseusWindow.maxWindowWidthRatio = 1.0
```

## Position-only centering

- `Hyper + Return` centres the focused window horizontally on its current
  screen without resizing it.

Only the window's `x` coordinate changes. Its width, height, and vertical
position remain unchanged. For example, a top quarter becomes a top-centre
quarter, while a bottom quarter becomes a bottom-centre quarter. This leaves
quarter-width columns on both sides—each exactly wide enough for the windows
produced by the eighths cycle.

`Hyper + Up` remains the separate command for creating a centred
half-width/full-height column, and `Hyper + Shift + Return` still maximizes.

## Optional Space indicator

The supplied `Hammerspoon/init.lua` enables a compact menu-bar label such as
`[2]`:

```lua
spoon.TheseusWindow.showSpaceIndicator = true
spoon.TheseusWindow:bindHotkeys():start()
```

Set `showSpaceIndicator` to `false` to disable it. The indicator has no hotkeys
and performs no Space switching. An `hs.spaces.watcher` triggers updates; the
label is recomputed from the ordered list of user Spaces rather than displaying
an opaque macOS Space ID. The square brackets provide a simple monochrome box
without consuming the width of the word “Space.” An unavailable Space is shown
as `[?]`; a full-screen/tiled Space is shown as `[—]`.

## Security and privacy

TheseusWindow runs locally and makes no network requests. It contains no
telemetry, credentials, account identifiers, or persistent logging of window
titles and frames.

TheseusWorkspace also runs locally and makes no network requests. It persists
the user-supplied workspace name, capture timestamp, application names and
bundle identifiers, per-application slot ordinals, and normalized window
geometry through `hs.settings`. It deliberately does not inspect or persist
window titles, paths, URLs, terminal working directories, or document content.
Recipes are local runtime data and are not stored in this public repository.

Hammerspoon's Accessibility permission is powerful: it allows these Spoons to
inspect and manipulate windows and allows TheseusWindow to synthesize mouse and
keyboard events.
The native Space transport briefly moves the pointer to the focused window's
title bar, holds that window, emits `Control + Left/Right`, releases the window,
and restores the pointer. Review the source before granting Accessibility
permission and install only code from a revision you trust.

## macOS and Hammerspoon limitations

- [`hs.spaces`](https://www.hammerspoon.org/docs/hs.spaces.html) is experimental
  and uses private APIs. TheseusWindow still relies on it to enumerate and
  verify Spaces, so a macOS update can break even the read/verification stages.
- macOS 27 currently breaks Hammerspoon's direct window-move and `gotoSpace`
  paths on this Mac. The isolated native-input transport avoids those two calls,
  but title-bar geometry and synthesized input are also OS-sensitive and must be
  retested after macOS or Hammerspoon updates.
- Hammerspoon needs Accessibility permission. Enabling **Reduce motion** can
  shorten the visible native Space transition.
- For stable ordering, enable **Displays have separate Spaces** and disable
  **Automatically rearrange Spaces based on most recent use** in Desktop &
  Dock → Mission Control.
- Full-screen/tiled Spaces and windows, sticky windows present on multiple
  Spaces, panels, desktop elements, minimized windows, and non-standard windows
  are rejected. The command does not force a move into an incompatible Space.
- Some applications enforce their own minimum sizes or frame placement.
  TheseusWindow reapplies the original frame, but macOS and the application
  remain authoritative.
- The implementation intentionally targets one monitor. Space lookup is scoped
  to the focused window's screen so a later multi-monitor policy can be added
  without changing the command sequence.
- If only the window move or only the Space transition succeeds, the timeout
  alert says which state was observed. The command does not attempt a second
  automatic move because that could displace the wrong window after a partial
  OS transition.

## Validation

Run:

```sh
mise install
mise run validate
```

The repository pins Lua 5.4.8 in `mise.toml`. You may also run
`./scripts/validate.sh` directly after installation, or set
`VALIDATION_LUA_BIN` to a compatible Lua executable.

The script compiles all Lua files and runs pure tests for ordered user-Space
filtering, left/right selection, non-wrapping boundaries, ordinal lookup,
forward/reverse stateful-cycle initialization, position-preserving horizontal
centering, stateless canonical size/position selection, outward tie-breaking,
axis-aligned directional focus, workspace-schema validation, normalized-frame
round trips and clamping, deterministic workspace slot assignment, missing
windows, and untouched extras. In particular, the first press of a stateful
reverse cycle starts at its final position, canonical forward/reverse cycles
wrap correctly without hidden state, diagonal focus candidates are rejected,
and horizontal centering changes only `x`. The validator deliberately does not
invoke Hammerspoon's `hs` command-line client: on affected macOS versions that
client can block before Lua evaluation while connecting to system services. No
live window, Space, or Hammerspoon settings store is manipulated by these tests.

Mocked-runtime tests also reject false-success reports for quietly ignored
frame requests and exercise delayed placement, post-call frame reversion,
bounded full-frame retries, separated resize/move fallback, cancellation,
visibility changes, and Space changes. They do not prove that a particular
application will accept a live macOS frame request.

Capture-dialog tests cover disabled naming/Save until readiness, one window
enumeration, moves and screen changes after readiness, frozen geometry across
replacement confirmation and save retries, catalog changes while naming,
cancel/close/stop cleanup, Space changes during collection, and failed discovery.
The frame-copy regression deliberately moves Ghostty's mocked geometry after
capture and confirms that Save retains the original coordinates.

The separated resize/move fallback was informed by Hammerspoon's
[frame-setting timing discussion](https://github.com/Hammerspoon/hammerspoon/issues/3731).
It uses non-blocking timers and verifies the outcome; no code from that
discussion was copied.

Validation levels are intentionally distinct:

- **Syntax:** every Lua file compiles.
- **Pure logic:** Space selection, geometry, and directional-window ranking
  pass without desktop manipulation.
- **Hammerspoon runtime/reload:** Hammerspoon evaluates the configuration and
  its console remains free of load errors.
- **Live integration:** a person confirms actual macOS window movement, Space
  activation, frame preservation, and focus. Loading alone does not prove this.

## Manual integration checklist

- [ ] From a middle user Space, move a standard window left and confirm the
      destination Space opens with that exact window focused.
- [ ] Move it right and confirm the same result and original frame.
- [ ] At the first Space, press `Hyper + Left`; confirm no move and a boundary
      alert.
- [ ] At the last Space, press `Hyper + Right`; confirm no move and a boundary
      alert.
- [ ] Create a new browser window on the wrong Space, then move/follow it in one
      command.
- [ ] On a window with no cycle history, press `Hyper + Shift + 2/3/4/8` and
      confirm the first result is the final position of that cycle; continue
      pressing to confirm reverse order and wrapping.
- [ ] Arrange overlapping rows and columns of windows, then use
      `Hyper + H/J/K/L`; confirm focus follows the nearest axis-aligned window,
      rejects diagonal-only candidates, and stays in the current Space.
- [ ] Use `Hyper + -` and `Hyper + Shift + -` from canonical and manually sized
      windows; confirm size cycling, reverse order, wrapping, and outward edge
      preservation.
- [ ] Use `Hyper + =` and `Hyper + Shift + =` for halves, quarters, eighths,
      and sixteenths; confirm the documented forward and reverse position
      orders without relying on prior key presses.
- [ ] Confirm minimized, full-screen, transient, and non-standard targets fail
      cleanly.
- [ ] Press `Hyper + Up`, then `Hyper + Down`; confirm centred layout and frame
      restoration.
- [ ] Place quarter windows at the top and bottom, press `Hyper + Return`, and
      confirm each window centres horizontally without changing width, height,
      or vertical position.
- [ ] Repeatedly press `Hyper + [` and `Hyper + ]`; confirm symmetric resizing,
      width limits, horizontal containment, and unchanged height/y-position.
- [ ] Traverse Spaces with native `Control + Left/Right`; confirm the menu-bar
      ordinal updates and that it creates no switching hotkeys.
- [ ] In an ordinary project Space, press `Hyper + Shift + R`; confirm the
      dialog opens with **Capturing…**, a disabled name field, and disabled Save.
      Wait for **Snapshot ready**, name/save the workspace, and confirm the
      completion notice reports the expected eligible count.
- [ ] Once the snapshot is ready but before saving, move a captured window.
      Save, then restore the recipe; confirm the window returns to the position
      from before naming, not the moved position. Repeat with replacement
      confirmation and verify it still uses the original snapshot.
- [ ] Cancel a capturing or ready dialog, press Escape, close its window, and
      repeat the capture shortcut while it is open; confirm no unsaved recipe
      is persisted and no duplicate capture dialog is created.
- [ ] Move and resize those windows, press `Hyper + R`, choose the recipe, and
      confirm all matching windows return to their captured relative frames,
      including background Ghostty windows. Wait for the verified completion
      notice; if any app is named as failed, inspect `lastRestoreReport`.
- [ ] Capture the same name again and confirm replacement requires an explicit
      confirmation rather than silently overwriting the recipe.
- [ ] Close one captured application window, restore the recipe, and confirm the
      result reports one missing slot without moving an unrelated replacement.
- [ ] Add an unrelated extra window, restore the recipe, and confirm it remains
      untouched and is counted as extra.
- [ ] Confirm capture in a full-screen/tiled Space fails cleanly and capture does
      not include sticky, minimized, hidden, transient, or other-Space windows.
- [ ] Reload Hammerspoon and inspect its Console for errors.

## Space-movement research and attribution

The stateful verification was informed by
[PaperWM.spoon](https://github.com/mogenson/PaperWM.spoon): verify the exact
window's destination membership, then retry exact-window focus. The native
title-bar-hold technique was informed by the historical
[Hammerspoon Space-movement discussion](https://github.com/Hammerspoon/hammerspoon/issues/235).
The implementation here was written for this smaller state machine; no PaperWM
tiling code, Mission Control title-matching code, or source text was copied.

PaperWM.spoon is Copyright © 2021 Michael Mogenson and distributed under the
[MIT License](https://github.com/mogenson/PaperWM.spoon/blob/main/LICENSE).
Because no PaperWM source code is included here, its license text does not need
to be redistributed; the project is credited as the research source.

## License

Both Spoons are available under the [MIT License](LICENSE).
