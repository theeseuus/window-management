# Window Factory candidate

A separate Swift/AppKit port of Factory Workspace. It leaves the tagged working
Hammerspoon implementation, deployed Spoons, recipes and global shortcuts alone.
This is an installed development candidate; Hyper+R opens the installed app; Hyper+Shift+R keeps the
Hammerspoon Window Factory available as fallback.

## Stable build, installation and updates

The local app lives at `/Applications/Window Factory.app`. Native layouts
live at `~/.local/share/window-factory-native/layouts.json`. The first stable
installation copied the six existing native layouts byte-for-byte from the
pilot catalog; that original pilot catalog remains recoverable. Hammerspoon's
settings database is neither read nor modified.

Build with the installed Apple SDK and repository-owned mise tools:

```fish
mise run native-build
mise run native-test
```

Output now defaults to `~/.cache/window-factory-native/build/Window Factory.app`,
outside the File Provider-managed source checkout. `WINDOW_FACTORY_BUILD_DIR`
can select another local output directory. Do not put signed app bundles in the
iCloud-managed source tree: Finder metadata previously invalidated their strict
signature checks and file pickers showed empty folders.

`signing-config.sh` records the selected public Developer ID Application
certificate fingerprint and Team, matching the signing route used by the
installed Freehold app. The build signs with Hardened Runtime and a secure
timestamp and verifies the Apple Developer ID/Team requirement. Only the Apple
Events automation entitlement is added for the existing scripting adapters.
Private keys are never exported or stored here. macOS owns signing-key access;
any key-access prompt belongs to the owner. There is no ad hoc fallback. Local
installation does not submit the app for notarization or publish an artifact.

Quit only Window Factory before installing or updating:

```fish
mise run native-install
open '/Applications/Window Factory.app'
```

The installer verifies the candidate and existing signatures, rejects a changed
designated requirement and symlink target, stages the replacement beside the
installed app, retains a verified previous app under the native data folder's
`install-backups`, and restores the previous app if replacement verification
fails. It refuses to replace a running native process. It never grants access,
registers a login item, or changes global shortcuts. Use the same bundle ID,
Team and signing route for subsequent updates; certificate rotation needs its
own reviewed check. Changing the build hash alone is no longer the app identity.

For a first installation with a separate native pilot catalog, the explicit
copy operation is:

```fish
./native/window-factory/install.sh --import-catalog "$PWD/native/window-factory/.build/pilot-data/layouts.json"
```

It validates through the candidate's schema decoder and refuses to overwrite a
different existing catalog. Original bytes stay untouched; use the app's Import
command for an intentional merge. This option does not migrate Hammerspoon data.

The ad hoc-to-Developer-ID transition requires one owner-granted Accessibility
entry for the installed Applications copy, followed by a restart. Per-app
Automation consent may be needed when using scripting adapters. A stable
requirement is the basis for permission continuity, but actual TCC retention
must be verified with a live signed update; signature checks alone do not prove
it. Keep Hammerspoon as fallback during that check.

A harmless synthetic preview is still available:

```fish
open '/Applications/Window Factory.app' --args --preview
```

Quit a running normal instance first. Preview uses synthetic layouts in memory,
with window operations and catalog changes disabled.

## Settings and visible keyboard commands

Open **Settings…** with **Command–comma**, from the app menu or library button.
It provides persistent, app-owned preferences for showing keyboard hints and
keeping the library above other windows, plus the effective app/layout paths,
Accessibility status, a permission-settings link, and Show Layout Folder.
Defaults keep hints visible and normal window level. These GUI preferences are
not a second writer for chezmoi configuration or global keybindings.

The Layout menu shows native keyboard equivalents. Action buttons and the
library footer display the main commands; the settings pane lists the full map:

| Command | Key |
| --- | --- |
| Capture | Command–N |
| Select layout | Up / Down |
| Restore existing windows | Return |
| Establish missing windows | Command–Return |
| Focus search | Command–F |
| Save a named capture | Return in the name field |
| Cancel or close | Escape |
| Delete selected layout, with confirmation | Command–Delete |
| Import / Export | Command–I / Shift–Command–E |
| Settings / Close window / Quit | Command–comma / Command–W / Command–Q |

Layout menu commands are scoped to the active library and disabled during a
capture/operation or in preview as appropriate. Settings remains available via
the app menu. The managed Hammerspoon loader now uses Hyper+R to launch this installed app
and Hyper+Shift+R to open the Hammerspoon fallback. This app registers no global
chord; holding Tab supplies the Hyper modifiers through Karabiner.

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

Hyper+R now opens this installed app through the managed launcher;
Hyper+Shift+R opens the Hammerspoon fallback. Karabiner and Raycast remain unchanged.
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


## Three-app desktop pilot and low-window correction, 2026-10-23

Owner-observed results with Rex Beta 0.1.0 build 1381, Safari 27.0.1
(build 22625.1.29.11.28), and the Codex-backed ChatGPT app 26.1016.62342
(build 21477):

- Dock reopening stays on the selected empty ordinary desktop after the
  `moveToActiveSpace` correction.
- Establish of the preparation layout opened all three apps' windows; Capture
  and Save produced the separate `Native desktop pilot` layout.
- Restore returned all three displaced windows correctly with no extra windows
  when they remained high enough on screen.
- Closing only the disposable Safari window, then Establishing, created the
  missing Safari window and placed all three correctly. The supplied receipt
  showed `3 placed · 1 created · 2 reused · 0 missing · 0 extra`.
- The owner confirmed that repeating Establish added no duplicates. The repeat's
  exact receipt counts were not supplied.

Restore had an eligibility defect: dragging a tall window low enough put its
centre below the usable screen, so collection excluded it even though it was
partly visible. The earlier screenshot reported two placed/reused and one
missing. The native filter now requires positive overlap with the selected
usable screen instead of centre containment. Windows entirely outside that
screen, with zero-area edge contact, or invalid geometry remain excluded;
current-Space, standard/visible, minimized/full-screen and identity checks are
unchanged. This shared collection fix also prevents Establish from treating
such a partially visible window as missing. A regression test reproduced the
old omission, then passed after the correction. Live low-window acceptance of
the corrected build is still pending; do not infer it from the other pilot
results.

Pilot packaging also exposed recurring Finder metadata and empty file-picker
contents in the iCloud-managed build folder. A verified copy outside that tree
was used for the successful pilot. Accessibility needed owner re-addition of
that local app followed by an app restart. Keep local pilot bundles outside the
synced build tree and verify their signatures; ad hoc rebuilds still require
permission checks. No production signing identity has been provisioned.
Hammerspoon files, runtime, shortcuts and saved layouts were not changed.

## Low-window live acceptance, 2026-10-23

The owner re-added the corrected local candidate to Accessibility. The same
local bundle passed strict signature verification and was restarted without
another rebuild; Capture, Restore and Establish were enabled, and the saved
`Native desktop pilot` layout remained selected.

Using that existing capture on the pilot desktop, the owner completed both
regression scenarios:

- Safari dragged low on screen, leaving its title bar and part of the window
  visible: Restore returned the windows correctly, with no missing windows or
  extras.
- Rex and Codex/GPT dragged low on screen: Restore again returned the windows
  correctly, with no missing windows or extras.

These owner-observed results close the pending low-window live acceptance from
above. Exact full receipt counts were not supplied for these runs; the reported
outcome is successful restoration with no missing windows or extras. No layout
recapture was required. Combined with the preceding three-app pilot, this
records successful Capture/Save, displaced-window Restore, missing-Safari
Establish, a duplicate-free Establish repeat, and both low-window Restore
regressions on the tested app/OS versions.

This is acceptance of the scoped Rex/Safari/Codex pilot. The other adapter
entries, multiple displays, production signing/permission persistence and
Hyper+R handoff remain unaccepted. Hammerspoon remains the working fallback;
no Spoon, Hammerspoon runtime, binding or saved Hammerspoon layout was changed.
The pilot app and its data remain isolated development artifacts.


## Stable local installation and settings checks, 2026-10-24

The Developer ID Application public leaf certificate was matched to the existing
installed Freehold signing route (Team `S5V98VJ2UV`, valid through September 2031).
No new key/certificate or key-access policy was created. Build 0.2.0/2 was signed
with Hardened Runtime and a secure timestamp and installed at the stable
Applications path. All six current native layouts copied exactly into the local
data folder. The temporary pilot and its catalog remain available for recovery.

Live UI checks verified Settings via Command–comma, shortcut hint visibility
and restoration, both preference controls, Escape from Settings, and search via
Command–F. The main buttons, footer, Layout menu and Settings show keyboard
commands. No live layout creation/movement was dispatched during these checks.

A changed 0.2.0/3 executable was then built and signed. Its designated requirement
is byte-for-byte identical to the installed build's requirement, while executable
SHA-256 differs. Core/catalog tests and seven installer rejection checks pass.
Initial Accessibility approval for the installed signed identity and a live
signed-update retention check are pending; matching requirements alone do not
establish permission retention. No Hammerspoon files, runtime, shortcuts or
Hammerspoon catalog were changed.


## Signed rename/update check, 2026-10-24

The owner requested the visible name `Window Factory`. Build 0.2.0/4 changes the
bundle filename, display name, library title and Quit menu to that name. The
bundle identifier `local.windowfactory.native`, Developer ID/Team, executable
name, data directory and preferences domain remain unchanged intentionally.
The guarded installer accepts `--previous-target` for this explicit move from
`/Applications/Window Factory Native.app` to `/Applications/Window Factory.app`.
It rejects ambiguous old/new installations or a symlink old app, verifies both
signatures and identical designated requirements, and retains the previous app
for recovery. On failure it restores the original path.

The signed update and path migration completed. Strict signature verification
passes. The pre/post designated requirements match exactly, and all six native
layouts match the pre-update catalog byte-for-byte and appear in the library.
The interface and app menu show Window Factory; no layout operations were run.

Permission acceptance remains open: after restarting the original installed
build, it already reported Accessibility denied while System Settings showed
its old named entry on. The renamed build likewise reports denied. This is not
a demonstrated loss of a working grant during update, and cannot be counted as
a permission-retention test. The owner has been asked to remove the old entry
and add the current signed Applications copy. A subsequent signed update must
start from verified enabled controls before claiming access continuity.
Hammerspoon remains unchanged throughout.

## Live signed-update acceptance, 2026-10-24

After the owner replaced the stale permission entry with the installed
`/Applications/Window Factory.app` entry and enabled it, build 0.2.0/4 was
restarted. Capture, Restore and Establish became enabled. Command–N performed
a real current-desktop capture of six windows; Escape cancelled it without
saving. This established a working baseline before the update.

Build 0.2.0/5 was compiled and Developer ID signed with the same certificate,
Team, bundle identifier and designated requirement. Its executable SHA-256
changed from `3b58b5dba543370ddd05898e8e70a90593dee17c9e02cb9d99779da84183d102`
to `46f17ff4538633a33b6169be0ab43e2148820477a4fd4ca69b70e292556bf5de`.
The normal guarded installer replaced the quit app at the same Applications
path, verified signatures and retained a verified previous bundle for recovery.
No permission setting was touched during this replacement or relaunch.

After relaunch, all three operation controls remained enabled. Command–N again
captured six real windows and Escape cancelled without saving. Settings showed
version `0.2.0 (5)`, the correct Applications path and `Accessibility: enabled`.
Both existing preference values were retained (keyboard hints and keep-on-top
were enabled). All six saved layouts remained visible, and catalog bytes match
the baseline exactly, including after both cancelled captures; SHA-256 is
`19b64c7cc973a977dc0fd0a46d99c20f68637397a2628768df8c9be2f4455867`.

This closes the pending same-identity signed-update Accessibility/layout
acceptance. It does not prove certificate rotation, notarized distribution or
all future OS versions. No Restore/Establish or other app-window mutation was
needed for this update check. Hammerspoon files, runtime, global bindings and
Hammerspoon saved layouts remain unchanged. Current default build is 0.2.0/5;
the visible product name is Window Factory.


## Managed launcher handoff, 2026-10-24

The owner selected the native app as the primary Window Factory. The approved
chezmoi loader uses Hyper+R (hold Tab + R) to dispatch `/usr/bin/open` with the
exact `/Applications/Window Factory.app` path. It handles a quit app as well as
reopening the library on the selected desktop. Hammerspoon owns this small
launcher binding; the native app still registers no global chord. The existing
TheseusWorkspace Spoon remains loaded on Hyper+Shift+R (hold Tab + Shift + R),
with its own recipes and original implementation. No app rebuild or additional
permission grant is required. The machine's canonical map and rollback are in
chezmoi `docs/reference/keyboard-shortcuts.md`; native/Hammerspoon catalogs stay
separate. TheseusWindow geometry/Space controls and general Raycast launchers
are unchanged. This handoff changes the managed loader only, not the portable
Spoon implementation or the historical baseline tag.
