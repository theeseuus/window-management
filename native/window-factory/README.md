# Window Factory

Window Factory is the installed Swift/AppKit app for saved layouts, direct window
controls, Space move-and-follow and the menu-bar desktop badge. Tab+R opens its
library or closes it when focused, while the app is running. Optional start at login is in Settings;
Tab+Shift+R retains the Hammerspoon library fallback when Hammerspoon is running.
The dated records below preserve implementation and physical acceptance evidence.

## Configurable shortcuts and compact Settings (build 25)

Settings has four tabs: General, Shortcuts, Layouts and About. General uses
concise labelled switches. Shortcuts offers all 30 global commands in the seven
existing groups, with a group switch and a recorder beside each action. Click a
binding, press a new combination, or Escape to cancel. Individual reset buttons
and a confirmed Reset All restore defaults. The Keyboard Shortcuts window reads
the same saved bindings, including changes after restart. Local library and
switcher navigation remains conventional and fixed.

The default chords, callback IDs and controller algorithms are unchanged.
Bindings use physical macOS key codes; display names currently use the US key
map. A versioned overrides envelope lives in app preferences, not chezmoi or the
layout catalog. Validation rejects duplicates (including disabled groups),
malformed entries, standard app/system commands and the retained Hyper+Shift+R
Hammerspoon fallback. Recording uses existing owned-hotkey callbacks plus a
Settings-window event monitor; it stops on Escape, focus loss, tab/window close
or key release. It does not request Input Monitoring or disable controller groups.
Registration changes preserve callbacks and session state; rejected drafts roll
back and are not persisted. Partial rollback failures are reported explicitly.

Import/Export/Last Report moved to Settings → Layouts. Delete remains in the
Layout menu and Command+Delete. About contains access status and diagnostics.
The library keeps Capture, Restore, Establish, Settings and Shortcuts; permanent
instruction footers and internal pilot labels are removed. Switcher grouping,
navigation and window-control primitives are unchanged.

## Stable build, installation and updates

The local app lives at `/Applications/Window Factory.app`. Native layouts
live at `~/.local/share/window-factory-native/layouts.json`. This compatibility
directory and the bundle ID `local.windowfactory.native` deliberately remain
stable to preserve layouts, preferences, backups and Accessibility identity. The first stable
installation copied the six existing native layouts byte-for-byte from the
pilot catalog; that original pilot catalog remains recoverable. Hammerspoon's
settings database is neither read nor modified.

Build with the installed Apple SDK and repository-owned mise tools:

```fish
mise run native-build
mise run native-test
```

Output now defaults to `~/.cache/window-factory/build/Window Factory.app`,
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
the app menu. Window Factory registers Hyper+R independently of the direct
control groups. Press again while the library is focused to close it; from
another app it brings the library forward. Hammerspoon retains only Hyper+Shift+R
for its library fallback.
Holding Tab supplies the Hyper modifiers through Karabiner. Start at login is
optional and initially off; a quit app must be reopened from the Dock/Applications.

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
  Space queries and the dedicated move-and-follow controller fail closed when
  their private bridge is unavailable. Layout operations do not transfer windows
  from other desktops. The separate Space controls verify actual membership,
  visible destination, original frame and exact focus.

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

Hyper+R is owned by the running Window Factory app; Hyper+Shift+R opens the
Hammerspoon fallback. Karabiner and Raycast remain unchanged.
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


### Physical shortcut acceptance, 2026-10-24

The owner confirmed that holding Tab + R opens the native Window Factory and
holding Tab + Shift + R opens the Hammerspoon fallback. Both normal physical
keyboard paths work; the earlier synthetic-input gap is closed. This record
changes documentation only. No application binary, runtime configuration,
layout catalog, Spoon implementation or additional controller feature changed.


## Complete controller port: geometry pilot, 2026-10-24

The selected sequence is geometry → directional focus → stash/restore → window
switching → Space move-and-follow/indicator. Preserve the existing keys and
accept each group on real disposable windows before continuing its handoff.
Configurable bindings and the broader library/settings UI redesign follow these
controller groups. Those later features are not implemented by this checkpoint.

The first group implements nineteen native geometry chords matching the
TheseusWindow contract, including canonical size/position and reverse cycles,
legacy 2/3/4/8 position cycles (shared per-window index, fresh reverse starts at
the last slot), centred-half plus saved-frame restore, horizontal centring,
80-point width adjustment, maximize and minimize. The horizontal-centre command
preserves vertical position and dimensions; Down falls back to a centred 85% by
90% frame if Up has not saved a frame in this app session. Per-window cycle and
restore state is memory-only, identified by process/window ID, and bounded.

Global Carbon hotkeys do not activate the library or install a keystroke
monitor. A callback snapshots the focused external standard window immediately;
foreground, exact window, visibility and current ordinary-Space membership are
checked before writes and verification. Credential apps and the controller's
own windows are excluded. Workspace operations and geometry operations cannot
run concurrently. Each direct command dispatches a bounded size/position change
and verifies the result, reporting refusal/minimum-size mismatch in a short
nonactivating HUD. There is no continuous enforcement or speculative Space move.

Registration is a single native group, disabled by default in a fresh profile.
Settings → Enable native geometry shortcuts activates/releases it, and the app
remembers successful activation. Failed registration removes all of this group's
registrations. The approved managed Hammerspoon loader releases only this group
with `spoon.TheseusWindow.geometryHotkeys = false`; the portable Spoon defaults
to true and keeps all its original algorithms. Directional focus, stash,
accordion, switching, Space movement and the indicator remain active there.
The loader starts a quit native app with `--background` when native geometry is
selected; this registers enabled controls without opening the library and adds
no login item. Quitting the native app releases its keys; Tab+R can relaunch it.

**Rollback:** release the native geometry group in Settings (or quit the native
app), change the managed loader's `geometryHotkeys` to true, apply and reload
Hammerspoon. Native geometry must stay disabled while the Hammerspoon group is
active. This restores the original shortcuts without touching catalogs. Tab+
Shift+R still opens the Hammerspoon workspace library, independently of this
controller-group switch.

Validation: 109 native geometry assertions include 96 comparisons generated by
the original Lua canonical helpers across wide, portrait, shifted-origin and
partly offscreen cases. Existing core/catalog/installer tests pass; the Spoon
lifecycle suite now has 83 assertions proving native release, retained unported
keys and restored fallback keys. Installed signed updates retained Accessibility,
all six catalog entries, their exact bytes and the enabled native setting.
Hammerspoon reloaded with only the geometry registrations absent; the native
app reported all nineteen exclusive registrations active after restart. This
is registration/compatibility evidence, not yet physical geometry acceptance.

The separate `Tests/WindowControlPilot.swift` app is a blank disposable window
with its own frame readout, no documents, terminal sessions or access grant.
Build it with `./native/window-factory/Tests/build-pilot.sh`; output is in the
local cache's `window-factory-native/geometry-pilot/Window Control Test.app`.
Close its red button to terminate it. The normal automated tests do not launch
it or manipulate live windows. A synthetic global-chord attempt did not change
its frame; as with the earlier launcher check, the physical key path requires
the owner. No live geometry success is claimed yet.

For the live pilot, focus this disposable window and keep Tab held for each
command. Try 2/3/4/8 and their Shift reverses; −/= and their Shift reverses;
Up then Down; horizontal-centre Return; bracket width steps; Shift+Return
maximize; and D minimize. Reopen the test app from its Dock icon after minimize.
Settings shows the last verified result or failure. Do not test against an
unsaved working document. Record differences before starting the focus group.

### Geometry first-press diagnosis and correction, 2026-10-24

The owner's physical pilot passed the geometry group except that thirds and
some other resizes sometimes reached a reduced frame on the first press and
needed another press. The owner quit Hammerspoon to rule out its interference;
it remained stopped throughout this investigation and native update.

A disposable standard AppKit window reproduced the issue with Hammerspoon
absent. AX size/position setters returned success even when the final frame was
wrong. Growing a low/right window was constrained at its old origin; rapid
successive AX setters also overlapped the application's frame animation. The
old native handler issued size then position immediately and checked once at
160 ms. Its geometry calculation tests did not exercise this application layer.
The Hammerspoon 1.1.1 frame helper additionally reapplies size and temporarily
manages AXEnhancedUserInterface. Merely adding that third immediate setter did
not fix this test app; its Enhanced UI disable request was unsupported. The
candidate does not change that application attribute.

Build 9 confines the correction to direct geometry controls. It moves, resizes,
then repositions, waiting for observed frames to settle between changes. Each
wait has a 400 ms minimum, three unchanged 40 ms samples and a 1.2-second limit;
position-only operations omit resize. Focus, exact window and current ordinary
Space are rechecked throughout, cancellation stops subsequent writes, setter
errors are reported and the final actual frame must match the target. Genuine
app size/position constraints remain failures rather than being reported as
success. This is a bounded response to a command, with no ongoing enforcement.
The wait can make a resize more deliberate; physical responsiveness remains an
owner acceptance check. Layout Restore/Establish placement and Rex adapters are
unchanged by this correction, as are the shortcuts and Hammerspoon fallback.

The automated suite adds 52 assertions covering a delayed application model,
clipping from different origins, all thirds, maximize/half/quarter targets,
real minimum-size refusal, focus loss and cancellation. The fixture also proves
that the previous immediate size/move sequence fails. The existing 109 geometry
assertions (96 Lua comparisons), core/catalog/installer tests and repository
validation pass. Installed build 9 retains Accessibility, all nineteen native
registrations and the exact six-layout catalog bytes. Physical acceptance of
the corrected geometry path is still pending.

Live application-layer validation used the exact production frame applier on
only the disposable test window: 24/24 cases passed (four starting origins ×
six targets: left/middle/right thirds, maximize, centred half and lower-right
quarter). Its original frame was restored afterward. No working app windows
were moved. This verifies the frame application primitive with Hammerspoon
stopped; it does not substitute for the owner's physical shortcut retest or
claim every third-party app has identical animation/minimum-size behaviour.

### Geometry responsiveness regression and replacement, 2026-10-24

The owner rejected build 9: its three mandatory settling waits made resizing
noticeably slow, another press during verification was rejected, and bracket
width changes on a centred half window appeared to fail. The 24-case primitive
check above established final geometry only; it did not establish acceptable
interactive performance. Build 9's settling strategy is superseded by build 10.

Build 10 submits the first frame immediately using a synchronous size-position-
size helper with scoped AXEnhancedUserInterface handling, following the original
Hammerspoon helper's approach. Unsupported Enhanced UI writes are left alone;
a successfully disabled attribute is restored before the helper returns. A
position-only request omits resize. Subsequent verification waits run after the
submission, and repair only one mismatched component per interval, for a bounded
maximum of two seconds. There is no mandatory wait before the first write.

A new geometry shortcut cancels the previous command's verification/repair
rather than being rejected as busy. For the same exact window, the new target
is calculated from the pending requested frame so repeated width/size commands
are cumulative even during an app animation. An operation serial prevents an
older task's cleanup from clearing a newer command. Workspace operations retain
their exclusion, and focus/identity/Space/cancellation guards still stop writes.

Validation: 100 frame-application assertions cover immediate dispatch, delayed
animations, width changes, constraints and interruption; existing native and
repository checks pass. The responsive production primitive passed 26/26 live
disposable-window cases, including narrower/wider from a centred half. After the
position-only optimization, a further three cases passed (both bracket targets
and position-only centring); the longest synchronous frame submission measured
17 ms in that small probe. This is submission time, not end-to-end animation
latency or keyboard acceptance. Both probes restored the original disposable
frame. Build 10 retains Accessibility, nineteen registrations and the exact six
saved layouts. Hammerspoon remained quit and unchanged. Physical key acceptance
and responsiveness in the owner's regular apps remain pending.

Binding check against the original Spoon: Hyper+Up sets the existing window to
centred half-width/full-height; Hyper+Return centres horizontally without
resizing; Hyper+Shift+Return maximizes. These geometry commands do not create
application windows. Plain Command+Return is not a geometry-controller binding;
in the Window Factory library it is Establish. No bindings changed in this fix.

### Build 10 physical geometry retest accepted, 2026-10-24

The owner confirmed that window commands now respond quickly, thirds work,
and both bracket width controls work from the centre and the other positions
tried so far. This closes the reported build 9 responsiveness/bracket regression
and the earlier first-press thirds issue in the normal keyboard path. Combined
with the preceding physical geometry checks, the geometry group is accepted
for continued use. This is scoped to the owner's tested cases, not a claim of
exhaustive compatibility across every app and position. The owner also reported
pushing the build 10 fix; the local branch matched its tracked remote before
this acceptance record. No binary, shortcuts, settings or Hammerspoon files
changed for this documentation checkpoint. Directional focus is the next group
in the approved controller-port sequence; it has not been handed over yet.

## Directional focus pilot, 2026-10-24

Build 11 adds native Hyper+H/J/K/L (hold Tab + H/J/K/L) for left/down/up/right
focus. These are the existing TheseusWindow shortcuts. The working geometry
controller, geometry calculations and responsive frame application are unchanged.
Focus has a separate four-key Carbon registry, preference and Settings checkbox;
its enable/disable/failure path never unregisters geometry's nineteen keys.
A fresh profile leaves focus disabled until selected, and a successful selection
is remembered across restart.

Selection ports `spatial_focus_logic.lua`: candidates must overlap on the
perpendicular axis and lie in the requested direction. Compare edge gap, centre
misalignment, larger overlap, then directional centre distance; exact ties retain
visible stacking order. Prefer a qualifying window on the source display, then
another currently visible display. With no aligned candidate, do nothing.

Candidate enumeration is on demand, limited to on-screen standard windows in
visible regular apps, with singleton membership in each display's captured
current ordinary Space. Hidden/minimized/full-screen windows, the controller,
Hammerspoon and credential apps are excluded. Only eligible app PIDs from the
on-screen window list are queried. Source focus, exact window identity and
captured desktops are checked before activation; target identity/eligibility
and exact resulting focus are verified. This group never writes window geometry,
creates a window, switches a Space or transfers a window. No continuous polling
or persistent window watcher is installed. Collection and verification remain
bounded by AX messaging timeouts and a short target-focus confirmation window.
Workspace capture/Restore/Establish and focus cannot run concurrently.

The portable Spoon wraps only its four directional bindings with
`focusHotkeys ~= false`, retaining the original focus implementation and default
fallback behaviour. The managed loader selects native focus with
`spoon.TheseusWindow.focusHotkeys = false`, independently of
`geometryHotkeys = false`. Hammerspoon remained quit during deployment. To
restore just focus to it, disable native directional focus in Settings, set
`focusHotkeys = true` in the chezmoi-managed loader, apply and reload Hammerspoon;
leave `geometryHotkeys = false` to retain native geometry. Do not enable both
owners for H/J/K/L. Canonical machine ownership/rollback is in chezmoi
`docs/reference/keyboard-shortcuts.md`.

Validation: 293 native focus assertions include 288 comparisons with the actual
Lua selector across shifted/scaled frames, candidate orders and invalid frames,
plus same-display preference, cross-display fallback, edge-touching rejection,
source exclusion and ties. The Spoon lifecycle suite has 113 assertions proving
independent release/restoration of focus and retention of geometry/other keys.
All existing native tests, 109 geometry assertions, 100 frame-application
assertions and repository validation pass. Chezmoi verification passes; the
expected uncommitted work was its only diagnostic warning before commit.
Installed build 11 retains Accessibility, the exact six-layout catalog bytes
and nineteen geometry registrations; the independent four focus registrations
were enabled in Settings. These are algorithm/registration checks. Normal
physical-key focus, its responsiveness and live cross-display selection require
the owner's pilot; no automated live focus success is claimed at this point.

### Focus activation correction, 2026-10-24

The owner reported applications refusing directional focus in build 11; Settings
showed the generic `Application refused directional focus` result. That guard
combined AXRaise success with `NSRunningApplication.activate(options: [])`, so
the message did not identify which dispatch step failed. This physical pilot
was a failure, not acceptance of the focus group.

Build 12 replaces that activation branch with the original Hammerspoon 1.1.1
front-window approach: mark the exact target main, attempt AXRaise without making
it a prerequisite, then `GetProcessForPID`/`SetFrontProcessWithOptions` with
`kSetFrontProcessFrontWindowOnly`, and reassert the selected main window. These
are the legacy Carbon process APIs used by Hammerspoon's `HSapplication
setFrontmost:` helper, not a new Space-movement capability. Deprecated API use
is isolated in the bridge. The caller retains eligibility/identity/current-
desktop guards and confirms the exact resulting focused window independently
of request return values. A failed confirmation now includes separate main,
raise and activation statuses and the target app name.

A live comparison on the existing disposable test app confirmed the revised
bridge focused its exact window (main 0, raise 0, activation 0); the prior focused
window was restored on the same desktop. The old AppKit request was accepted
in this small probe, so it did not reproduce the owner's specific failing
app/dispatch step. The probe initially read stale foreground state while blocking
its event loop; running the event loop corrected that diagnostic error. This
is limited activation evidence, not normal physical-key acceptance in Rex,
Safari, Codex or every app. The owner must retest the directional shortcuts.

All native tests and repository validation pass, including the 293 directional
focus, 109 geometry and 100 frame-application assertions. Installed build 12
retains Accessibility, 19 geometry and 4 focus registrations. The geometry
controller/algorithms/frame handler, catalog and managed fallback are unchanged.
Hammerspoon remains quit.

### Build 12 physical directional focus retest accepted, 2026-10-24

The owner confirmed that directional focus changes now work and geometry still
behaves as expected. This accepts the normal physical-key focus path after the
build 12 activation correction and confirms that the accepted geometry group
continues to work. Acceptance covers the owner's tested windows and directions;
it is not an exhaustive claim across every app, display or edge case.

This checkpoint records the result only: no app binary, shortcut, preference,
layout or Hammerspoon implementation changed. Hammerspoon remains available as
the independently selectable fallback. Stash/restore is next in the agreed
controller-port sequence and has not been handed over yet.

## Stash/restore and shortcut reference pilot, 2026-10-24

Build 13 ports only Hyper+S (hold Tab + S) as a stash/restore toggle. The original
Spoon saves the focused window's frame, requests a position 40 points beyond
the display's usable right edge without changing y/size, and restores that
saved frame on the next toggle. Native stash preserves this contract. The
observed macOS constraint leaves a 40-point strip visible instead of moving the
entire window past the edge; this is accepted without repeated corrective moves.
Hyper+Shift+S remains Hammerspoon's accordion command, which is not ported here.

Stash has its own single-key Carbon registry, Settings switch and remembered
activation preference. The accepted geometry and directional-focus source
implementations are unchanged; their registries are not released by stash.
A fresh profile leaves stash disabled. The managed loader independently selects
native stash using `stashHotkeys = false`. The portable Spoon retains its
original stash implementation and default binding behind `stashHotkeys ~= false`.
Restore native stashed windows before disabling/quitting/updating or selecting
the fallback. For rollback, disable native stash in Settings, set the managed
`stashHotkeys = true`, apply and reload Hammerspoon; keep accepted geometry/focus
ownership unchanged. Hammerspoon remains quit during this pilot.

Saved frames are memory-only for this app session and keyed by process/window
identity. Restoration deliberately permits an offscreen *recorded* window while
retaining exact AX identity, app identity, standard-window, hidden/minimized/
full-screen and captured ordinary-Space checks. Other-Space windows are not
moved or followed. New stash requests that would land on another display are
refused rather than spilling a window onto it. Frame writes are immediate;
verification is bounded. Failure retains the original saved frame for recovery,
and a newer toggle cancels the preceding verification. Successful restoration
removes its record only after the original frame is confirmed. Closed records
are skipped when recovering the most recent remaining live window.

A separate **Keyboard Shortcuts** window is available from the library's
Shortcuts… button, Settings' Keyboard Shortcuts… button and Window menu. The
menu configures Command+? while Window Factory is active. Its scrollable,
selectable reference shows all nineteen geometry commands, H/J/K/L, stash,
library commands and the remaining Hammerspoon commands, with current native
group status and whether Hammerspoon is running. Geometry rows come directly
from the existing shortcut definitions. Escape closes the reference. Its
Restore last stashed window button provides an explicit recovery action after
focus has moved elsewhere, including when the stash hotkey has been disabled.
No new global binding is assigned to the reference. Configurable bindings and
the broader UI redesign remain later work.

Validation: all native tests and required repository checks pass, including
37 stash-geometry assertions for exact requests, macOS-constrained placement,
shifted displays and refusal of size/y mismatches. The Spoon lifecycle suite
has 139 assertions, covering independent stash release/restoration, retained
geometry/focus and retained Shift+S accordion. Existing 109 geometry, 100 frame-
application and 293 directional-focus assertions still pass. The exact production
stash controller was exercised on the disposable Window Control Test: stash
retained one saved frame, recovery restored its exact original frame and the
saved count returned to zero. This is programmatic controller evidence, not
physical-key acceptance in every app.

Installed build 13 retains Accessibility, the exact six-layout catalog bytes
and enabled 19 geometry + 4 focus registrations; the independent stash key was
enabled in Settings. The reference was visually inspected for readable content,
scrolling and fixed recovery/close controls. Opening it from Settings and closing
it with Escape worked. A synthetic Command+? attempt did not open it; its normal
physical menu-key path remains unverified, and the button/menu paths are
available. Physical stash/restore, recovery after a focus change, and retained
geometry/focus behaviour remain the owner's acceptance check. Chezmoi verification
passes with only the expected pre-commit dirty-worktree diagnostic warning.

### Build 13 physical stash/restore retest accepted, 2026-10-24

The owner confirmed that stash and restore work, geometry and directional focus
still work as expected, and the shortcut reference window is useful. This accepts
the normal physical stash/restore path and the reference window for continued
use, alongside the previously accepted geometry and focus groups.

This confirmation does not separately establish the Command+? physical menu-key
path or recovery-button behaviour after a focus change; those specific checks
remain unverified. No app binary, bindings, preferences, saved layouts or
Hammerspoon implementation changed for this documentation checkpoint. The
independent Hammerspoon fallback remains available. Window switching is next
in the agreed controller-port sequence and has not been handed over yet.

## Window switching pilot, 2026-10-24

Build 15 adds the existing Hyper+W / Hyper+Shift+W window switcher as a separate
native group. Keep Tab held, cycle forward/backward, then release the modifiers
to activate the selected window. The candidate list is frozen during a gesture,
wraps in both directions and selects the next/previous entry relative to the
current window. Escape cancels while Tab or Tab+Shift is still held; temporary
plain/Shift/Hyper/Hyper+Shift Escape registrations exist only during the picker.
Clicking a row also selects it. The new group's registrations are exclusive and
independent of the accepted geometry, directional focus and stash registries.
The source implementations for those three groups are unchanged.

The nonactivating panel shows app icons, titles, selected position and whether
a window is on the current or another Space. It does not activate Window Factory
or move a working window while choosing. Previews use ScreenCaptureKit only
after `CGPreflightScreenCaptureAccess` confirms existing access, and only for the
selected eligible app/window identity. No access request is made; missing access
or capture errors retain the app icon. Images are temporary UI state, not saved.
The panel was rendered with harmless sample rows for visual inspection; live
keyboard interaction and preview capture require their own acceptance evidence.

The original Hammerspoon switcher includes windows across Spaces. Native
collection therefore considers regular apps' standard windows across readable
ordinary/full-screen Spaces, excluding hidden/minimized windows, credential
apps, native controller/Hammerspoon windows and ambiguous/non-singleton Space
membership. AX-only windows can still be included if absent from the global
window metadata list. Window IDs, app identity and membership are revalidated
before activation. No window geometry, minimization, unhide, creation or Space
transfer is performed. Native front-window activation intentionally may follow
the selected window to another Space, then verifies both its exact focus and
current target Space. This cross-Space allowance belongs only to the switcher;
directional focus retains its accepted current-desktop restrictions.

Ordering uses the current window first, observed recency, then initial window
stacking order. Recency is bounded, memory-only and updated on app activation,
invocation and successful switching; it is not a complete historical record of
every within-app focus change before invocation. There are no persistent AX
window watchers. Source focus/current desktops and workspace availability are
checked while collecting and choosing; manual changes cancel the session.
Modifier polling runs every 20 ms only while choosing. Activation verification
is bounded at 1.2 seconds and does not enforce focus continuously.

Settings → Enable native window switching shortcuts remembers successful
activation; fresh profiles leave it disabled. The shortcut reference now lists
native switching separately and still identifies **accordion as unported**:
Hyper+Shift+S stays in Hammerspoon, along with window Space movement and its
indicator. The portable Spoon gates only W/Shift+W behind
`switcherHotkeys ~= false`, preserving the original UI/algorithm for fallback.
The managed loader uses `switcherHotkeys = false` for this pilot. To restore only
switching, disable native switching, set the managed flag true, apply and reload
Hammerspoon. Leave accepted geometry/focus/stash ownership unchanged. Hammerspoon
remains quit during this deployment. The canonical machine map and rollback
are in chezmoi `docs/reference/keyboard-shortcuts.md`.

Validation: 968 switcher assertions cover initial forward/reverse selection,
repeated wrapping, direction changes, empty/missing/duplicate identities,
recency ordering and bounded history. The 170-assertion Spoon lifecycle suite
checks independent switcher release/restoration and retained geometry, focus,
stash, accordion and Space bindings. All existing native tests and required
repository validation pass. The production collection/activation services
collected nine eligible windows and focused only the disposable Window Control
Test target, confirmed exact focus, checked its frame was unchanged and restored
prior focus. This was a current-desktop probe; live cross-Space switching is not
yet claimed. A separate native registration probe passed geometry, focus, stash,
switcher, all Escape variants and switcher re-enabling, and verified releasing
the switcher retained the other three groups. It released its probe keys.

Installed build 15 retains Accessibility, the exact six-layout catalog bytes,
enabled 19 geometry + 4 focus + 1 stash keys and the independent two switcher
keys. There were zero session stashes before restart. Chezmoi verification passes
with only the expected pre-commit dirty-worktree warning. Physical forward/
reverse selection, modifier release, Escape cancellation, cross-Space activation
and retained existing controls remain the owner's pilot check. Preview capture
with pre-existing Screen Recording permission has not been live-validated here.

### Build 15 physical switcher retest: same-Space pass, cross-Space gap, 2026-10-24

The owner confirmed forward/backward cycling, release-to-select and Escape-to-
cancel work in the normal physical keyboard path. Geometry, directional focus
and stash/restore still behave as expected. This accepts the switcher interaction
for windows on the current Space and retains the earlier control-group acceptance.

The owner also reported that Tab+W lists windows only on the current Space;
windows on other Spaces are absent. **Cross-Space discovery is an open defect,
not accepted functionality or an untested success.** The implementation and
reference UI intend to include those windows, but that intention is not the
observed result. Cross-Space activation cannot be accepted while discovery
omits its targets. The earlier same-desktop service probe and selector tests do
not close this gap. Native switching has not yet reached full parity with the
original Hammerspoon cross-Space switcher.

Next investigation: determine where eligible other-Space windows are lost in
collection, membership validation or display mapping, then run an owner-observed
cross-Space discovery/activation test without changing the accepted controls.
No cause is established by this report. The original independent Hammerspoon
switcher fallback remains available. Accordion remains unported.

This checkpoint records the result only; no app binary, shortcut, preference,
layout or Hammerspoon implementation changed. The owner reported pushing the
implementation; both local repositories matched their tracked remotes before
these documentation updates.

## Cross-Space discovery correction, 2026-10-24

The build 15 omission was an application of the wrong discovery source: on this
Mac, AXWindows omits live windows on desktops that are not currently shown.
Changing to the array-specific AX getter did not repair it. Hammerspoon's own
[window-filter source](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/window/window_filter.lua)
notes this limitation and retains windows as Spaces are visited. The native
switcher was collecting a fresh AX list and had no equivalent away-window
inventory. Relaxing minimized or dialog filters would not supply the missing
ordinary windows and would admit the wrong objects.

A read-only WindowServer census proved the difference: several live Finder,
Safari, Codex and Chrome windows on other desktops were absent from the AX list.
The per-Space `SLSCopyWindowsWithOptionsAndTags` read distinguishes windows that
are up (`0x2`) from all hosted windows including parked ones (`0x7`). The
existing native helper already uses this API and the desktop-selection protocol;
[KiwiDesk's census source](https://github.com/KiwiCanopy/KiwiDesk/blob/main/Sources/KiwiDeskCore/OS/SkyLight%2BWindowCensus.swift)
also documents this distinction. The correction independently uses those API
signatures; no KiwiDesk implementation is copied.

Build 16 makes the live compositor census authoritative for discovery, intersected
with layer-0 owner metadata, exact singleton Space membership, valid bounds and
an eligible regular app identity. Parked, hidden, closed/ghost and credential
windows remain excluded. Current-desktop entries still require an exact standard
AX window. An unseen ordinary-desktop entry can instead retain its existing
WindowServer ID, PID, bundle and native display/Space identity until selected.
Unavailable census reads produce an error rather than a silently incomplete
current-desktop list. Discovery itself never visits desktops or changes focus.

Only after selection does the switcher use the previously proven WMBridge
`ManagedDisplaySetCurrentSpaceOperation` plus `HideSpacesOperation` protocol to
visit that ordinary desktop. It then resolves the *same* window ID in the app's
AX windows/main/focused references, requires standard/non-minimized identity,
uses the accepted native focus request and verifies exact focus plus destination
Space. No window-transfer operation, frame write, creation, unhide or unminimize
is involved. It never substitutes a different app window when resolution fails.
Other displays' captured desktops remain guarded. Desktop arrival and focus
verification are bounded; no continuing focus enforcement is installed.

This new metadata-only reveal path is limited to ordinary desktops, the scope
of the existing helper proof. Full-screen windows already available through AX
retain their original activation path; unseen full-screen metadata is not
promised. Titles may initially be `Window on Desktop N` when neither AX nor
permitted WindowServer metadata supplies one; real observed titles are cached
in memory. No new Screen Recording or Accessibility grant is requested.

A clean read-only probe using the corrected production collector found 16
eligible windows: eight current-desktop AX windows and eight other-desktop
metadata entries (four Finder, one Safari, one Codex/ChatGPT, one Chrome and
one Mail). None of those desktops was visited for discovery. The added regression
case explicitly accepts a live away window absent from AX while rejecting
parked, wrong/ambiguous membership, ghost and known nonstandard windows. All 979
switcher assertions, existing native tests, 170 Spoon lifecycle assertions and
required repository validation pass.

Installed signed build 16 retains Accessibility, enabled registrations and the
exact six-layout catalog. There were zero session stashes before restart.
The source implementations of geometry, directional focus and stash/restore,
and their existing membership/frame/focus bridges, are unchanged. The managed
Hammerspoon fallback is unchanged and Hammerspoon remains quit. The earlier
same-Space physical acceptance remains recorded; the new end-to-end other-Space
reveal/resolve/focus path awaits the owner's physical pilot. Discovery is now
live-verified, but cross-Space activation is not yet marked accepted.

### Build 16 physical cross-Space retest accepted, 2026-10-24

The owner confirmed that other-Space windows now appear, selecting one reaches
the correct desktop and focuses that window, and same-Space switching still
works. Geometry, directional focus and stash/restore also continue to behave as
expected. This accepts the ordinary-desktop discovery/reveal/exact-focus path
in the normal keyboard workflow and closes the reported build 15 discovery
defect for the owner's tested cases. It is not exhaustive full-screen,
multi-display or every-app coverage.

The owner supplied screenshots and two usability observations that remain open:

- Right-edge stashing leaves part of the window visible; left-edge stashing was
  reported to leave no visible portion. The right-edge result matches the
  previously observed macOS constraint. The native Tab+S implementation is a
  right-edge toggle; this report does not establish a native left-stash mode
  or a tested cause for the directional asymmetry. Compare the two placements
  separately before changing the accepted stash behaviour.
- The native cross-Space picker is harder to interpret than the Hammerspoon
  version. The screenshot shows generic This Space/Other Space suffixes,
  long window titles/paths, an inconsistent mix of real titles and Window on
  Desktop N fallbacks, and a selected-window header without a clear desktop
  identifier. Functional switching is accepted; window/desktop identification
  needs a separate UI refinement. A consistent explicit desktop label for every
  row and the selected header is a concrete next design direction, not an
  implemented change.

This checkpoint records acceptance and the open observations only. No app binary,
bindings, preferences, saved layouts or Hammerspoon fallback changed. The owner
reported pushing both implementation commits; both local repositories matched
their tracked remotes before this documentation checkpoint. Accordion remains
unported. Command+? and recovery-button behaviour after a focus change retain
their separately unverified status from earlier records.


### Build 17 grouped, persistent window picker, 2026-10-24

The native picker now groups windows by display and Desktop number, using the
existing Space census order rather than private numeric Space IDs. Each group
marks the current desktop and shows its window count; multiple displays receive
display prefixes. Recency order is retained within each group. The selected
header names the desktop, app and window separately, with group and total counts.
Unavailable and full-screen locations receive explicit labels instead of false
desktop numbers.

At the owner's request, this supersedes the native hold-and-release interaction:

- Tab+W opens the picker; releasing Tab leaves it open. Tab+W again dismisses
  without switching.
- Up/Down moves through windows; Left/Right moves between desktop groups.
- Return or keypad Enter selects and closes; Escape dismisses without switching.
- Tab+Shift+W remains a backward open/step command. Clicking a row still selects.

The Window menu also exposes Switch Windows, and the shortcut reference and
picker footer describe the new commands. A nonactivating key panel receives
plain navigation keys locally, without new global arrow registrations or an
Input Monitoring request. Desktop changes and loss of keyboard focus dismiss
the picker. Geometry, directional focus and stash commands pause only while the
picker is open, preventing changes underneath it.

The accepted discovery and exact-window activation service, native bridge,
geometry/focus/stash implementations and Hammerspoon fallback are unchanged.
The fallback retains its original hold-and-release picker. The owner prefers
the visible stash edge as a retrieval handle; no stash placement changes are
included. Accordion remains unported.

Validation: 999 switcher assertions cover grouping, ordering, identity-preserving
selection, navigation, both Enter keys and cancellation; the full native tests
and repository validation pass. An isolated render of the production panel
confirmed clear grouping and keyboard focus without changing the active app.
The production build is signed successfully as build 17. Physical toggle,
arrow-key and cross-Space selection acceptance remains pending.

Deployment is held with build 16 running: one window has a session-only saved
stash frame that must be restored before quitting. No installed app, saved
layouts, preferences or working Hammerspoon configuration has been changed by
this checkpoint.


### Build 17 installed and restarted, 2026-10-24

After the owner restored the stashed window, the running shortcut reference
confirmed zero session stashes. The guarded installer replaced the quit app
with signed build 17 at `/Applications/Window Factory.app`. The restarted
Settings pane reports version 0.2.0 (17), Accessibility enabled, and all four
native control groups enabled. Strict signature verification passes, and the
six-layout catalog retains its exact pre-update SHA-256
`19b64c7cc973a977dc0fd0a46d99c20f68637397a2628768df8c9be2f4455867`.
Hammerspoon remains stopped and its configuration unchanged. A physical keyboard
pilot of persistent toggle, arrows, Enter selection and dismissal is requested;
installation checks alone do not establish acceptance of that interaction.


### Build 17 physical keyboard pilot accepted; scrolling defect open, 2026-10-24

The owner confirmed that Tab+W leaves the picker open after key release, arrows
navigate desktop groups and windows, Enter selects correctly, and Tab+W again
or Escape dismisses. This accepts those keyboard interactions in the owner's
tested cases. Build 17 remains installed; Hammerspoon is unchanged.

The owner also reported that arrow navigation makes the list scroll past like a
roulette wheel before reaching the next item. Functional selection passes, but
scroll presentation remains an open defect. Source inspection found that every
selection render recreates all rows, replaces `scroll.documentView`, and then
requests visibility of the selected row together with its group heading when
that combined rectangle fits. Replacing the document on every step is a likely
source of viewport resets, with the heading request potentially amplifying the
travel; this is a source-based diagnosis, not a verified live reproduction.
A targeted follow-up should retain the document and viewport while updating the
selection highlight, scrolling only enough to expose a row outside the visible
area. This checkpoint changes documentation only; no runtime, bindings, layouts,
stash behaviour or Hammerspoon files are changed.


### Build 18 minimal picker scrolling, 2026-10-24

Arrow navigation now retains the picker document and row views throughout the
open session. Rendering changes the selection highlight and selected-window
header without rebuilding the scroll contents. The viewport remains still for
a fully visible row; a row beyond its edge moves it immediately by only the
amount needed to expose that row. Group headings are no longer pulled into
view on every selection. Initial rendering starts at the top before revealing
the initial selection, and closing clears the document for a fresh session.

This fixes the document-reset path identified after the owner's build 17
roulette-wheel scrolling report. Navigation mapping, selection, cross-Space
discovery/activation, geometry, directional focus, stash and Hammerspoon fallback
are unchanged. No private bridge or managed Hammerspoon file changes are included.

The native suite passes, including 999 switching assertions and 127 new
regression assertions against the actual AppKit picker document and viewport.
Those checks retain document identity, verify no scrolling for visible rows,
minimal upward/downward movement across group boundaries, wrapping and group
jumps, repeat selection and short-list/session reset behaviour. The panel tests
show no windows and control no real application windows. Repository validation
and the signed production build pass.

Before updating, the running reference confirmed zero session stashes. Build 18
was installed at the existing Applications location and restarted. Settings
confirm Accessibility and all four native groups remain enabled; strict
signature verification passes and the six-layout catalog is byte-for-byte
unchanged. Hammerspoon remains stopped. A physical arrow-scrolling and switching
regression pilot is requested; its acceptance is pending.


### Build 18 physical scrolling retest accepted, 2026-10-24

The owner confirmed that scrolling is now normal and the switcher controls
still work. This accepts the build 18 scrolling fix in the owner's normal
keyboard workflow, alongside the previously accepted persistent Tab+W toggle,
window/desktop arrow navigation, Enter selection and Escape dismissal. The
reported roulette-wheel scrolling defect is closed for these tested cases.
Build 18 remains installed and running. This checkpoint changes documentation
only; Hammerspoon, bindings, application code, preferences and saved layouts
are unchanged.


### Build 19 independent accordion pilot, 2026-10-24

Tab+Shift+S now has a separate native accordion controller, Settings switch and
shortcut-reference section. The focused standard window remains the anchor and
is never resized, moved or refocused. Other visible standard windows from the
same running app on the anchor's current ordinary desktop/display are sorted
top-to-bottom then left-to-right, given its size, and offset right/down by
28/22 points per step. Placement uses the original Lua screen clamp; exact
position ties use window identity for repeatability. Other apps, minimized,
hidden, full-screen, off-desktop and credential windows are excluded. This
pilot deliberately does not gather windows across displays or Spaces.

All fan frames are submitted before the 400ms verification wait. The controller
checks exact app/window identity, desktop membership, continued anchor focus and
unchanged anchor frame before writes and after settling. User focus/desktop or
anchor changes cancel further work. A rejected/constrained frame is reported
as incomplete; the implementation does not repeatedly fight app constraints.
No restore history or document/session state is created.

The Carbon registration uses an independent signature and registry. The accepted
geometry, directional-focus, stash and switcher implementations are unchanged;
accordion is blocked while the picker or a layout operation is active. The
portable Spoon defaults to its original behaviour; `accordionHotkeys = false`
releases only Shift+S in the managed loader. To fall back, disable native
accordion in Settings, set the managed flag true, apply and reload Hammerspoon.
Do not enable both owners for the same key. Hammerspoon was not started or
reloaded for this pilot.

Validation: 38 native accordion assertions include 18 exact comparisons against
the original Lua callback run with fake windows, including sorting, clamping,
negative display origins, oversized anchors and one-window behaviour. Existing
native suites (including 999 switching and 127 viewport assertions) pass. Spoon
lifecycle coverage passes 199 assertions, proving independent accordion key
release and restoration while retaining every accepted group and Space keys.
The repository validation and signed build pass. Build 19 is installed at the
stable Applications location, Accessibility and all four earlier native groups
are retained, accordion is enabled, and the six-layout catalog is byte-for-byte
unchanged. Zero session stashes were confirmed before restart. A three-window
disposable pilot is open for physical testing; acceptance remains pending.

The current machine migration checklist is maintained in the chezmoi
`docs/reference/keyboard-shortcuts.md` reference: Space move-and-follow, the
menu-bar Space indicator, and launcher/startup ownership remain to migrate.
The Hammerspoon layout library and original direct controls remain deliberate
fallbacks. Configurable bindings and the planned UI cleanup are later product
work, separate from porting the remaining controller functions.


### Build 20 accordion stacking correction, 2026-10-24

The owner confirmed build 19 accordion placement works, but supplied a Chrome
screenshot showing inconsistent overlap order. Placement followed the fan while
the inherited front-to-back window order did not. The owner agreed to an explicit
stacking pass: raise farthest to nearest, then restore the anchor frontmost and
focused. This is a native refinement; the original Lua fallback is unchanged.

Build 20 retains the existing frame plan, shortcut and scope. After verifying
frames, it raises the fan in reverse placement order, then the anchor, without
yielding between raises. It rechecks identities, desktop, front app and anchor
frame during that pass. The final anchor-focus request uses the existing bridge
function; no bridge implementation changes are needed. Bounded read-only checks
then compare the compositor's actual front-to-back IDs with anchor/nearest/next
order and confirm exact anchor focus. Unconfirmed order is reported as a stacking
failure even when frame placement succeeded. There are no repeated stacking
repair loops or Space transfers.

Validation passes: 46 accordion assertions cover expected raise order (including
clamped/tied placements and single-window no-op), retaining the 18 original Lua
frame comparisons. All native suites and repository validation pass. The accepted
geometry, directional focus, stash and switcher implementations, bindings and
Hammerspoon fallback remain unchanged. Physical stacking acceptance is pending.

Deployment is held with build 19 running: the shortcut reference reports one
session-only stash. The owner has been asked to restore it before restart. The
build 20 candidate is prepared; no installed app or saved layout changes are
included in this checkpoint.


### Build 20 installed and restarted, 2026-10-24

After the owner reported restoring the stash, the reference initially still
showed one saved frame. The normal Restore last stashed window action completed
with “Restored Google Chrome”; reopening the reference confirmed zero session
stashes before quitting. The guarded installer then replaced the app with signed
build 20 at the stable Applications path. Signature verification passes, and the
restarted Settings pane reports Accessibility enabled and all five native groups
enabled, including accordion. The six-layout catalog retains its exact previous
SHA-256, and Hammerspoon remains stopped. No control or fallback source changes
were made during this deployment. A physical test of staircase overlap, anchor
frontmost/focus, repetition and accepted-control regression is requested;
acceptance remains pending.


### Build 20 physical accordion stacking retest accepted, 2026-10-24

The owner confirmed correct staircase stacking with the anchor frontmost and
continued operation of the switcher, geometry, focus and stash controls in the
requested repeat/regression pilot. This accepts the native accordion placement
and stacking path for the tested cases and closes the reported overlap-order
issue. Build 20 remains installed. This checkpoint changes documentation only;
application code, shortcuts, preferences, saved layouts and the Hammerspoon
fallback remain unchanged. Space movement, the Space indicator and launcher/
startup ownership remain the migration work listed in the keyboard reference.


### Build 21 independent Space move-and-follow pilot, 2026-10-24

Tab+Left/Right now has a separate native controller, Settings switch, persisted
preference and shortcut-reference section. It selects the non-wrapping adjacent
ordinary desktop in the focused window's display order, skipping full-screen
Spaces. The focused window must be standard, visible, unminimized, not full-screen,
and exclusively on the current ordinary desktop. Credential/own/Hammerspoon apps
and ambiguous membership are rejected.

The transport ports the successful isolated WMBridge proof, not the Hammerspoon
mouse-drag/Control-arrow workaround. It dispatches one exact-window bridge move,
requires two consecutive destination-membership samples before following, then
uses the existing set-current/hide-origin bridge pair. Two visible-desktop
samples must confirm the moved window is onscreen and sampled source windows
are hidden. Only then does it restore the original frame if needed and request/
verify exact-window focus. All waits are bounded; topology, identity, foreground
app and source/destination consistency are checked throughout. An incomplete
move/follow/focus is reported truthfully; no automatic rollback, alternate
transport, input synthesis or background polling is added. Private APIs remain
conditional on the installed OS; dispatch is never treated as success.

The new bridge registration and operation are independent. The accepted
geometry, directional-focus, stash, switcher and accordion implementation files
are unchanged. Main integration prevents those commands from acting during a
Space transaction, and prevents movement while the picker or library operation
is active. Outside that transaction their behaviour is unchanged. The portable
Spoon retains its original Space algorithm and default keys; the managed loader
sets `spaceMoveHotkeys = false` to release only these two arrows. Fallback:
disable native Space movement, set that managed flag true, apply and reload
Hammerspoon. Hammerspoon was not launched or reloaded during the handoff.

Validation passes: 45 new movement assertions cover boundaries, native ordering,
full-screen skipping, ambiguous membership, exactly one move/follow dispatch,
two-sample verification, bounded timeouts, rejected dispatch, cancellation,
user-change aborts and focus failure. All prior native suites pass, including
999 switching, 127 viewport and 46 accordion assertions. The Spoon lifecycle
suite passes 229 assertions, proving independent Space-key release/restoration
while retaining the accepted groups. Repository validation and signed build pass.

Installed build 21 retains Accessibility, all five earlier native groups, the
stable app identity and byte-for-byte six-layout catalog. Native Space movement
was enabled as the sixth group. Zero session stashes were confirmed before
restart. A separate disposable Space Move Test app is open for the physical
round trip, original frame/focus, native Control-arrow and accepted-control
regression pilot. Physical acceptance remains pending; the normal validation
suite does not move real windows or switch desktops.

After this pilot, the remaining Hammerspoon migration work is the menu-bar Space
indicator and native launcher/startup ownership. The Lua library and original
controls remain retained fallbacks, not missing native layout features.


### Build 21 physical Space move-and-follow pilot accepted, 2026-10-24

The owner confirmed the disposable-window round trip, retained original frame
and exact focus, user-only native Control+Left/Right navigation, and continued
operation of geometry, directional focus, stash, switcher and accordion in the
requested regression pilot. This accepts native Tab+Left/Right move-and-follow
for the tested ordinary-desktop scenario. It is not exhaustive app, multi-display,
OS-version or boundary-behaviour coverage beyond the automated policy checks.
Build 21 remains installed. This checkpoint changes documentation only; code,
shortcuts, preferences, layouts and the Hammerspoon fallback are unchanged.
The remaining Hammerspoon migration work is the menu-bar Space indicator and
launcher/startup ownership; original controls and the Lua library remain fallbacks.


### Build 22 native menu-bar Space indicator pilot, 2026-10-24

The menu-bar indicator now has its own persisted General setting and a separate
read-only native component. It retains the transparent rounded outline, centred
13-point numeral and macOS template-image appearance. Numbers are ordinals in
native ordinary-desktop order, excluding full-screen Spaces and opaque IDs.
The tooltip gives the ordinal, total and display name; `?` reports unavailable or
ambiguous data and `—` identifies a known full-screen/tiled Space. Malformed
metadata never becomes an invented desktop number.

Refresh is event driven: immediate reads plus one cancellable 100ms settling
read on Space changes, app activation, wake, display changes and this app's key
window changes. Native move-and-follow and switcher completion explicitly
reconcile even if macOS emits no Space notification; directional focus also
refreshes display choice. There is no permanent timer, keyboard interception,
predictive counting or desktop/window mutation. Where existing AX access is
available, the front app's focused-window frame selects the display; credential
apps are excluded, and the fallback is NSScreen.main/first. No new permission is
requested. Same-app cross-display manual focus changes and rapid intermediate
traversal retain their separate physical coverage limits.

Images are cached by label and cleared on stop. Disabling removes the status
item, observers and settling task without releasing any shortcut group. The
badge menu opens the library, Settings or shortcut reference; it does not offer
Space-switching actions. All accepted control implementation and bridge files
are unchanged. Only Main callback wiring reconciles the indicator after relevant
commands. The Hammerspoon indicator algorithm is unchanged; the managed loader
sets `showSpaceIndicator = false`. Fallback: turn the native indicator off, set
that managed flag true, apply and reload Hammerspoon. Do not enable both badges.

Validation passes: 1,064 pure state assertions cover desktop ordering/counts,
full-screen exclusion/marker, unknown types, invalid IDs, duplicate/current
ambiguity and tooltips. Fifteen real AppKit image assertions check template
rendering, dimensions and transparent corners for one/two/three digits and both
markers, bringing that panel suite to 142 assertions. All existing native suites
and repository validation pass. The normal tests create no status items and do
not move windows or switch desktops.

Build 22 was signed, installed at the existing Applications path and restarted
after confirming zero session stashes. Strict installed signature verification
passes; Accessibility, all six enabled control groups and the exact six-layout
catalog are preserved. The indicator was enabled and reported Active user Space
3 of 7 on LG ULTRAFINE. Settings disable/re-enable passed independently of the
controls, leaving it enabled. Hammerspoon remains stopped. Physical badge/menu,
desktop traversal, native command updates and regression acceptance are pending.
After this pilot, launcher/startup ownership is the remaining Hammerspoon port;
the Lua library and original controls remain retained fallbacks.


### Build 22 physical menu-bar indicator pilot accepted, 2026-10-24

The owner confirmed that the badge updates correctly, its menu works, and the
existing controls still work. This accepts the native Space indicator and its
Window Factory menu access for the tested workflow. Full-screen markers,
multiple-display focus changes and rapid intermediate traversal retain their
separate coverage limits beyond the automated state/image checks. Build 22
remains installed with the indicator enabled. This checkpoint changes only
documentation; application code, shortcuts, preferences, layouts and the
Hammerspoon fallback are unchanged. Launcher/startup ownership is the remaining
functional Hammerspoon port, with the Lua library and original controls retained
as fallbacks.


### Builds 23–24 launcher/startup ownership and naming audit, 2026-10-24

Window Factory now owns Tab+R through an independent Carbon registration and
persisted launcher setting. The managed Hammerspoon loader retains its exact
Tab+Shift+R library fallback but no longer binds primary R or starts Window
Factory. A mocked execution of that actual loader verifies the retained fallback,
all earlier ownership flags and absence of launcher/task side effects. Hammerspoon
remains stopped; its library and control implementations are unchanged.

Start Window Factory at login uses SMAppService.mainApp and is optional. Status
is read from macOS rather than inferred from a saved checkbox. Enable/disable
uses the standard registration APIs; approval-pending state is displayed with a
Login Items Settings button. No registration occurs on startup/install. The owner
chose to leave it off, and the installed app reports no login registration found.
Recognized login Apple-event markers and --background keep the initial library
closed; real sign-in launch/registration is untested while the option stays off.
See Apple's [main-app service](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
and [login launch marker](https://developer.apple.com/documentation/coreservices/keyaelaunchedasloginitem).
Native Tab+R is available only while this process runs; after quitting, reopen
from Applications/Dock. This is a deliberate difference from an external launcher.

The owner physically accepted build 23 primary Tab+R opening, repeat opening,
the existing controls and badge, and login startup off. Subsequent steering adds
build 24's Show Dock icon option and Tab+R toggle. The toggle closes only the
visible, focused library on the active desktop while this app is active. It
brings a background/away library forward and leaves modal panels alone. Closing
uses the existing library close path (including cancellation of an in-progress
operation); it does not quit the app. Badge Open Window Factory remains a show
action rather than a toggle.

Show Dock icon defaults to on. Turning it off uses accessory activation policy
to hide the Dock/Command+Tab entry; badge and launcher remain available. The
preference is applied before the app event loop on subsequent launches. Its off
state survived an actual quit/reopen and was restored to the visible default.
The enlarged Settings contents now scroll within the display, keeping startup
options and all earlier controls reachable.

Naming scan: current product/UI labels and active guide headings use Window
Factory. The executable is WindowFactory; build and future pilot caches use
~/.cache/window-factory. The installer reads the signed bundle's executable name
and guards both current and legacy executable names during updates/imports.
The stable bundle ID local.windowfactory.native and existing
~/.local/share/window-factory-native data directory are deliberate compatibility
exceptions preserving preferences, permissions, catalog and install-backup history.
Legacy executable guards, dated records, the branch and stable document paths
retain historical identifiers; no layout migration or branch rename was performed.

Checks pass: 19 installer guards, 11 launch-policy assertions, six synthetic
login-event checks (no event is sent), real Settings viewport checks and three
Dock-preference assertions within the 153-assertion AppKit suite, plus all prior
native suites and repository validation. Dock/activation preference was exercised
without login registration. Build 24 is installed, strict signature verified,
Accessibility retained, six control groups plus launcher and indicator enabled,
and the exact six-layout catalog unchanged. The executable rename preserves the
designated signing requirement; existing access survived. The normal build 23
launcher passed the owner's physical test; build 24 toggle/Dock physical
acceptance is pending. Existing control and bridge primitives are unchanged;
only a separate launcher registry and app integration were added.


### Build 24 physical launcher-toggle and Dock pilot accepted, 2026-10-24

The owner confirmed Tab+R opens/closes correctly, brings the library forward
from another app, Dock visibility works while retaining badge/launcher access,
and existing controls continue to work. This accepts the build 24 toggle and
Dock options for the tested workflow, alongside the earlier build 23 native
launcher acceptance. Login startup remains off as requested; real login-item
registration and sign-in startup remain untested. Hammerspoon's original
Tab+Shift+R binding is retained and its loader handoff is verified; Hammerspoon
was not started for a new physical fallback test. No functional Hammerspoon port
remains for the normal workflow. The Lua implementation remains a recovery
fallback; configurable keybindings and further UI refinement are later work.
This acceptance checkpoint changes documentation only.

### Build 25 verification

Repository validation and the full native suites pass, including 181 AppKit
assertions, saved-binding/default/collision checks and a fake-Carbon registry
suite covering live reconfiguration, cancellation routing, duplicate Escape
callback IDs, rejection, rollback and explicit rollback failure. These registry
tests do not register real OS shortcuts. Existing geometry/focus Lua comparisons
and all prior control suites remain unchanged and passing.

The signed candidate was installed at the stable app path. A temporary Library
binding to Hyper+F18 updated the Settings row and Keyboard Shortcuts immediately,
survived a signed update/restart, and a conflicting Hyper+S was rejected without
changing it. The row reset restored the original Hyper+R. The six-layout catalog
is byte-identical to the accepted baseline. Accessibility access survived;
all seven shortcut groups are enabled, Dock visibility and login startup remain
off, and Hammerspoon source/runtime ownership was not changed. General and
Shortcuts were inspected in the installed AppKit UI. Modifier symbols and the
chosen key have a separating space in both views. Recorder focus is explicitly
acquired on click; Escape is reserved for cancellation while recording.

The final installed recorder was checked: clicking acquires keyboard focus;
Escape cancels recording and leaves Settings open. A fresh owner check of
physical shortcuts and the simplified Settings interface remains pending.
Automated input changes app focus,
so it does not establish the normal physical-key interaction result.


### Build 25 owner check and build 26 corrections, 2026-10-25

The owner confirmed Settings/shortcut editing, improved modifier spacing, and
continued operation of the other controls. Space move-and-follow lost foreground
focus after movement, so its earlier acceptance does not cover this reported
case. The installed diagnostic receipt was: “Move/follow dispatched. Focus,
application or window eligibility changed; Space command stopped.”

The foreground-app guard was applied throughout the asynchronous desktop
transition. Moving the focused window away can itself change the foreground
app, so the guard could stop the intended focus restoration. The finishing
check also accepted an app-local AXFocusedWindow, which can name a background
window. Build 26 keeps strict initial focus and exact window/Space eligibility,
but permits transition-driven foreground changes. New keyboard presses or mouse
button presses cancel the operation, using public event counters without reading
key contents or installing an event tap; modifier releases and autorepeat do not
increment the keyboard counter. Destination confirmation precedes restoration.
A bounded focus sequence now requires both the foreground app and system-wide
Accessibility focused window to match the moved window for six samples. Late
focus loss resets the samples and permits at most three activation requests in
25 polls. Actual desktop order, membership, frame and cancellation checks remain.
No shared focus bridge or other controller implementation was changed.

The shortcut reference now uses real tab stops and hanging indents instead of
spaces, keeping action text aligned across Shift and unshifted bindings and when
wrapped. Accessibility status/settings access moved from About to General.
185 AppKit assertions include actual glyph-column positions and permission-control
placement; 61 Space-movement assertions cover late focus loss, stable recovery,
timeout, intervening input and cancellation. All prior native suites and Lua
repository validation pass. Build 26 was installed with strict signature and
Accessibility retained; the owner's current seven-layout catalog was byte-identical
before/after. Current app preferences and Hammerspoon were left unchanged.
Installed typography and General were inspected. Physical chained Space moves
are pending the owner's normal keyboard check; offline tests do not prove that
macOS retains real desktop focus.


### Build 26 physical Space-focus retest accepted, 2026-10-25

The owner confirmed that all chained moves retain the same window's focus
without clicking it again. This accepts the build 26 move-and-follow focus fix
for the tested normal-keyboard workflow. The owner also observed a short
“replenish” delay when attempting the next move too quickly.

The controller remains single-flight: a shortcut received while a move is still
active is not queued. Destination verification is followed by six consecutive
40 ms focus samples (at least 240 ms in addition to the desktop transition and
other checks). New keyboard/button input during that operation can cancel the
remaining verification. Rapid-repeat responsiveness is therefore a recorded
limitation, not a claim of seamless queued movement. No timing, queue, controller,
shortcut or Hammerspoon changes were made for this acceptance checkpoint.

## Agent command-line access

There is no supported agent control CLI or IPC endpoint yet. The executable
supports offline `--validate-catalog`, UI `--preview`, an alternate `--data-dir`,
and quiet `--background` launch. The latter runs the GUI-session app without
opening its library; it is not a command endpoint. Live capture, Restore,
Establish, window controls and structured operation receipts are not exposed to
agents. The earlier Space proof/helper programs are separate diagnostics, not
Window Factory's public automation interface.

The intended extension is one CLI client talking to the installed app's existing
operation owners, returning structured results and avoiding a second app instance
or duplicate shortcut registries. UI-free control still requires a logged-in
WindowServer session and the app's existing Accessibility permission. This is
future work, not part of build 26.
