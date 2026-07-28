# TheseusWindow

TheseusWindow is a Hammerspoon Spoon for deterministic macOS window placement,
window switching, and native Space movement. The reference configuration keeps
responsibilities separate:

- Karabiner defines key semantics. Holding Tab emits Hyper
  (`Control + Option + Command`).
- Raycast launches applications.
- Hammerspoon and this Spoon manipulate windows.
- Native macOS `Control + Left/Right` moves only the user between Spaces.

The complete reference map is in [SHORTCUTS.md](SHORTCUTS.md). Its application
launch shortcuts document one example setup and are not implemented by this
Spoon.

## Requirements

- macOS with native Mission Control `Control + Left/Right` shortcuts enabled.
- Hammerspoon with Accessibility permission; version 1.1.1 is the tested
  release.
- At least two ordinary user Spaces for move-and-follow commands.
- A Hyper-key mapping if using the reference bindings. The supplied setup uses
  Karabiner-Elements to make held Tab emit
  `Control + Option + Command`; Karabiner configuration is not included.

## Installation

1. Copy `Hammerspoon/TheseusWindow.spoon` into
   `~/.hammerspoon/Spoons/TheseusWindow.spoon`.
2. Merge the following lines into your existing `~/.hammerspoon/init.lua`;
   do not overwrite unrelated Hammerspoon configuration:

   ```lua
   hs.loadSpoon("TheseusWindow")
   spoon.TheseusWindow.showSpaceIndicator = true
   spoon.TheseusWindow:bindHotkeys():start()
   ```

3. Reload Hammerspoon and grant Accessibility access if macOS requests it.
4. Work through the manual integration checklist below before relying on native
   Space movement.

If dotfiles are managed by chezmoi or another configuration manager, add these
files to its source state and deploy them through that manager.

## Features

TheseusWindow provides cross-app window switching, deterministic geometry
cycles in both directions, stash/restore, accordion layout, a centred
half-width layout, maximize/minimize, geometry restoration, width adjustments,
and spatial arrow controls.

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

Hammerspoon's Accessibility permission is powerful: it allows this Spoon to
inspect and manipulate windows and to synthesize mouse and keyboard events.
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
filtering, left/right selection, non-wrapping boundaries, ordinal lookup, and
forward/reverse cycle initialization. In particular, the first press of a
reverse cycle now starts at its final position rather than incorrectly starting
at position 1. The validator deliberately does not invoke Hammerspoon's `hs`
command-line client: on affected macOS versions that client can block before
Lua evaluation while connecting to system services. No live window or Space is
manipulated by these tests.

Validation levels are intentionally distinct:

- **Syntax:** every Lua file compiles.
- **Pure logic:** ordered-Space selection and boundaries pass without desktop
  manipulation.
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
- [ ] Confirm minimized, full-screen, transient, and non-standard targets fail
      cleanly.
- [ ] Press `Hyper + Up`, then `Hyper + Down`; confirm centred layout and frame
      restoration.
- [ ] Repeatedly press `Hyper + [` and `Hyper + ]`; confirm symmetric resizing,
      width limits, horizontal containment, and unchanged height/y-position.
- [ ] Traverse Spaces with native `Control + Left/Right`; confirm the menu-bar
      ordinal updates and that it creates no switching hotkeys.
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

TheseusWindow is available under the [MIT License](LICENSE).
