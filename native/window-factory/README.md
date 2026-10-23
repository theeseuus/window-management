# Window Factory Native candidate

A separate Swift/AppKit port of Factory Workspace. It leaves the tagged working
Hammerspoon implementation, deployed Spoons, recipes and global shortcuts alone.
This is a source-built development candidate, not the default Window Factory.

## Build and preview

From the repository root, with the installed Apple SDK and trusted repository
mise tools:

```fish
mise run native-build
mise run native-test
open 'native/window-factory/.build/Window Factory Native.app' --args --preview --data-dir "$PWD/native/window-factory/.build/preview-data"
```

The preview uses three synthetic layouts in memory. Search, selection, outlines,
arrows and Escape are available. Capture, Restore, Establish and catalog changes
are disabled; it does not query or move another application's windows. Quit the
preview before starting a normal pilot:

```fish
open 'native/window-factory/.build/Window Factory Native.app' --args --data-dir "$PWD/native/window-factory/.build/pilot-data"
```

The normal pilot starts with a separate empty library. Its stable bundle ID is
`local.windowfactory.native`; Accessibility must be granted by the owner before
capture/placement. The app checks access without prompting. Its Settings button
only opens the relevant system pane. Specific AppleScript adapters can require
per-app Automation consent when used. No grants, login items, installations or
global shortcuts are created by the build. Current local signing is ad hoc;
permission persistence across rebuilds still needs validation.

## Implemented contract

- Capture eligible standard windows on the selected ordinary desktop/display;
  exclude hidden, minimized, full-screen, other-Space, own and credential-manager
  windows. Freeze the snapshot before naming; cancel does not save.
- Search layouts/applications, select with arrows, preview normalized outlines;
  Return restores existing windows, Command–Return establishes missing ones,
  Escape cancels an operation/capture or closes the library. Double-click
  restores; Command–Delete requests confirmed deletion. No context menu yet.
- Save with explicit replacement confirmation, validated import/merge, export,
  confirmed deletion and an in-memory last report. Save atomically, retain a
  previous catalog, reject an observed conflicting on-disk update.
- Match one window to at most one slot, preserve extras, create only missing
  current-desktop slots. Refuse ambiguous app instances. Bound discovery and
  placement attempts; never repeat a dispatched New Window command after a
  discovery timeout. Cancellation stops future work; it does not undo completed
  launches/moves. Display counts and failures instead of inferring success from
  an Accessibility setter's return value.
- Recheck selected Space and exact window membership around placement. Private
  SkyLight is used only for queries in this candidate; Space transfers remain
  in the separate proof and Hammerspoon. Unsupported queries fail closed.

The full 16-entry registry is generated at build time from
`Hammerspoon/TheseusWorkspace.spoon/app_adapters.lua`. The committed
`Resources/adapters.json` is a reviewed snapshot; the build rejects drift.
Change canonical operations in the Lua registry and regenerate the snapshot
with the following command, then review the diff:

```fish
mise exec -- lua native/window-factory/scripts/export-adapters.lua Hammerspoon/TheseusWorkspace.spoon/app_adapters.lua > native/window-factory/Resources/adapters.json
```

Unknown function-based adapters fail export rather than silently losing logic.
Runtime uses bundled JSON and has no Hammerspoon/Lua dependency. Safari retains
its normal default-profile New Window menu; Ghostty retains its 1.3/scripting
gate; Mail creates viewer windows; Claude retains its launch-only limitation.
The existing bounded Rex placement policy is carried over, without claiming
that the startup movement is solved.

## Data and adoption

Default native data is `~/.local/share/window-factory-native/layouts.json`,
created only on the first save/import. Use the explicit repository `.build`
pilot directory above during development. No native catalog is checked in.

Import accepts the existing schema-v1 catalog JSON and copies/merges it into the
native store. Conflicting names stop the import. Hammerspoon currently stores
its catalog under the exact `hs.settings` key `TheseusWorkspaceRecipesV1`;
there is no automatic database scan or production migration. A deliberate
export of that key can supply an import file in a later adoption step. Existing
Hammerspoon settings remain its own store; the two apps never share a writer.

The build is checked with Swift 6 language mode, warnings as errors, strict
Objective-C warnings and bundle signature verification. Core tests cover schema,
names, geometry/matching and registry compatibility. Those checks do not prove
live capture, permissions, creation, placement or duplicate prevention. Record
native pilots separately from the older Hammerspoon/private-helper evidence.
The initial live smoke test is Rex/Safari/Codex; the full adapter list still
requires compatibility checks before claiming native parity.

Hyper+R continues opening Hammerspoon. Karabiner and Raycast remain unchanged.
Use this app's Dock icon during the pilot. Move the binding only after live
acceptance, releasing the old owner before registering the native chord.
The broader TheseusWindow controls remain available throughout.

See the [build/transition plan](../../docs/native-window-factory.md) for scope
and the [adapter guide](../../docs/app-adapters.md) for existing app contracts.

## Development check, 2026-10-23

The local bundle built and passed strict signature verification. The native
suite passed 22 core assertions and 11 catalog recovery/conflict assertions;
the existing `mise run validate` suite also passed. In the running synthetic
preview, search typing/filtering, Command–A and Up/Down selection were verified.
The check caught and fixed a missing standard Edit menu. Automated observation
reactivates/reopens a closed app window, so Escape/lifecycle acceptance still
needs the owner's normal input path. No live capture, Restore or Establish was
run with this candidate; no Accessibility/Automation permission was granted.


## First desktop pilot: library activation correction

The owner reported that reopening the native library from the Dock on an empty
desktop switched back to its original working desktop. The retained NSWindow
had default Space collection behaviour. The candidate now sets AppKit's
`moveToActiveSpace` before its first presentation, so activating the library
should bring that window to the selected desktop. This affects only the native
library, not app windows or Hammerspoon. The correction needs a repeat of the
owner's Dock path before the three-app pilot proceeds; no live Capture/Restore/
Establish result is claimed yet.
