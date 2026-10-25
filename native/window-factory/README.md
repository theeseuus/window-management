# Window Factory

Window Factory is the installed Swift/AppKit app for saved layouts, direct window
controls, Space move-and-follow and the menu-bar desktop badge. Tab+R opens its
library or closes it when focused, while the app is running. Optional start at login is in Settings;
Tab+Shift+R retains the Hammerspoon library fallback when Hammerspoon is running.
The dated records below preserve implementation and physical acceptance evidence.

## Migration status and next work

Reviewed against both retained Spoons and the managed loader on 2026-10-25.
The TheseusWindow controller and core TheseusWorkspace workflow are implemented
and accepted in Window Factory. No core controller group remains to port.

| Capability | Native status |
| --- | --- |
| Size/position cycles, centring, frame restore, width, maximize/minimize | Accepted |
| Directional focus | Accepted |
| Stash/restore | Accepted; visible-edge behavior still varies with app/macOS constraints |
| Window switching, desktop groups, cross-Space activation | Accepted; persistent picker, arrows, Return/Enter, Escape and Tab+W toggle |
| Accordion | Accepted, with anchor frontmost and ordered stacking |
| Space move-and-follow | Accepted; rapid repeated presses can be ignored while a move is verifying |
| Menu-bar Space badge and app access | Accepted |
| Library launcher, Dock visibility, optional login startup | Tab+R and Dock visibility accepted; actual login startup remains untested; Settings observed enabled on 2026-10-25 |
| Capture, Restore, Establish, repeat without duplicates | Accepted Rex/Safari/Codex desktop pilots; all 16 adapters shipped, broader live coverage remains |
| Configurable keybindings and reference | Accepted; 31 global commands, Tab+/ toggles reference |
| Library presentation | Thumbnails/icons, Delete/context menu, name-ranked search, optional proportional preview and drag ordering accepted |
| Binary-tree tiling | Build 42 Rex and mixed Rex/Safari/Codex pilots accepted: tiling, split resizing, stash/restore rejoining for all three apps, Safari float/rejoin; earlier Rex pilot also covered open/close reflow and previous-position restoration |
| Applications and launch shortcuts | Tab+A search, Tab+T Rex activation and Tab+S clash rejection accepted; build 41 installed with bindings retained |
| Agent CLI | Read-only/off-switch checks and live Rex Capture/Restore/Establish/repeat passed; see [CLI.md](CLI.md) |

Hammerspoon retains recoverable original implementations and Tab+Shift+R for
its library when running. The managed loader releases all seven direct-control
and indicator owners to Window Factory. Restoring a direct-control group still
requires releasing its native binding before enabling its Spoon fallback.
Karabiner owns hold-Tab → Hyper. Window Factory can own individual app-launch
shortcuts; Raycast retains bindings not explicitly handed over. macOS owns
Control+Left/Right. Those are separate integrations, not unfinished Spoon ports.
The canonical app-adapter definitions still live in Lua and generate bundled
JSON; the installed app does not require Hammerspoon to run.

Remaining verification and polish, before adding a new feature:

- Extend tiling acceptance beyond Rex/Safari/Codex to other apps, empty-desktop
  activation and display changes. Mixed-app stash/restore rejoining is accepted.
  Observe whether the order of panel operations needs refinement during ordinary use.
- Exercise the other installed app adapters; current live pilots do not establish
  native compatibility for every entry. Include failure/cancellation cases.
- Validate multiple displays, display changes and full-screen/unsupported-Space
  rejection in a separate harmless pilot.
- Test actual sign-in startup separately. Settings was observed enabled on
  2026-10-25; the migration did not change its registration.
- Review rapid-repeat Space movement responsiveness without weakening focus,
  membership or intervening-input checks.
- Keep Rex startup movement as a known visual limitation; verified final frames
  do not mean the startup jump has been solved.
- Review deliberate, consistent visible stash edges. The current native command
  requests a right-edge stash and accepts macOS constraints; it does not promise
  a chosen visible strip width or provide a left/right stash selector.
- Observe the new app-local keyboard ordering and Space-preview interaction
  in ordinary use; no core migration work remains.

Deferred feature choices:

- **Custom geometries:** add user-defined size/position geometries later.
- **Layout editor:** drag/resize the saved window rectangles with save/cancel
  and undo; separate from ordering layout rows.
- **Application state:** browser URLs, terminal commands and selected chats.
- **Coordinated animation:** presentation after reliable final placement.
- **Distribution:** notarization/updating beyond the current signed local installer.


Implementation and dated pilot receipts are preserved in
[development history](DEVELOPMENT.md); the [original transition plan](../../docs/native-window-factory.md)
is historical planning, not the current backlog.

## Binary-tree tiling

Open **Tiling…** from the Space badge menu or Window menu. Enable the **Tiling session** switch on the intended ordinary desktop. The first version owns one
explicit desktop/display session at a time. It starts off and never re-enables
a session at app launch. Enabling on an empty desktop waits for new windows;
enabling on an occupied desktop adopts its eligible windows in a balanced tree.
Dialogs, sheets, credential apps, full-screen and all-Space windows are excluded
by the shared window eligibility rules. No apps are launched by tiling.

The panel shows a proportional tree. Click a tile or select its window in the
list. Drag a divider and release to change its split. **− / +** changes the
selected window's nearest split by five percentage points. **Side by side** and
**Top / bottom** change that split's axis and the direction for subsequent
insertions. **Balance** resets split ratios; **Swap** exchanges the selected
window with the next tile. New windows split beside the selected tiled window;
closing a window collapses its branch. Hidden/minimized windows are temporarily
omitted from placement and can rejoin their retained tree position.

**Float / Rejoin** releases or rejoins a window. Existing geometry shortcuts
float their target synchronously before running their unchanged placement logic.
Manual pointer moves/resizes also float a window after the input settles.
Stash temporarily parks a window and restores its tree position when retrieved.
Accordion, Restore and Establish pause tiling before they arrange windows.
**Pause** retains the tree without placing windows; **Resume** reconciles the
current inventory. **Restore previous positions** restores surviving admitted
windows to their pre-tiling frames and leaves tiling paused. Turning the switch
off releases the session and leaves current frames in place.

Settings → Tiling contains window gaps, outer margins, the new-split axis and
excluded application bundles. Settings persist independently of layout recipes;
removing an exclusion does not silently rejoin a previously floating window.
App minimum-size constraints cannot all be predicted. Plans reject undersized
rectangles before writing, and an unfulfilled frame request pauses tiling with
an error. It does not endlessly reapply a rejected arrangement. Returning to an
inactive tiled desktop triggers reconciliation; display changes require an
explicit resume. Multi-display tiling, saved tree templates and tiling CLI
commands are outside this first version.

Panel keys are local: arrows select a window, −/+ resize its split, V/H set the
axis, B balances, S swaps, F floats/rejoins, P pauses/resumes and Escape closes.
They appear in Keyboard Shortcuts. No new global chords are registered, and all
existing bindings and the Hammerspoon fallback remain unchanged.

### Implementation boundaries

| Component | Owns | Does not own |
| --- | --- | --- |
| `TilingTree.swift` | Pure tree edits and frame plans | macOS access, UI, preferences |
| `TilingController.swift` | Session lifecycle, admission, floating, pause and undo | AX elements or widget actions |
| `TilingBackend.swift` | Desktop/window adapter and event observation | Tree policy or saved recipes |
| `TilingPanel.swift` | Tree display, divider input and Settings controls | Direct window writes |
| `TilingFeature.swift` | Composition and explicit handoffs from existing owners | Alternate geometry or layout engines |

The adapter reuses `MacServices.collect`, `Context`/`LiveWindow` eligibility and
`DirectFrameApplication`. Observers exist only while a session is enabled;
notification bursts are debounced rather than serviced by continuous polling.
Existing controllers expose small optional handoff callbacks; their algorithms
and shortcut registration remain their own. Pure geometry and an injected
backend exercise the state machine without desktop mutations. Offline tests do
not establish live app compatibility; physical acceptance is recorded separately
in DEVELOPMENT.md.

## Applications and launch shortcuts

Applications is a separate search window: type a name, use the arrows and press
Return to launch or bring that app forward. Escape closes it. It includes
installed apps without shortcuts and keeps Return in the layout library mapped
to Restore. Open it from the library's Applications button or Window menu
(Command+Shift+A); its global toggle is configurable in Settings → Applications.
The accepted initial handoff is Tab+A for search and Tab+T for Rex Beta.
Rex’s old Raycast binding was released; other Raycast bindings remain with Raycast.

In Settings → Applications, choose Add Application, record a shortcut and enable
its switch. Recording a binding does not enable it automatically. Clear Shortcut
also disables it; Remove forgets that app's launch entry. The search command can
be disabled or cleared. Up to 64 application entries are supported. App identity,
selected location, chords and enablement persist in app preferences independently
of layout recipes. Re-selecting a moved app updates its location while preserving
its binding. Keyboard Shortcuts reads the same records and shows inactive entries
as Off.

Clash checks run in both directions between application bindings and existing
Window Factory commands, including disabled entries, reserved local commands and
the Hammerspoon fallback. Failed OS registration keeps the previous binding where
possible and reports the failure. External conflicts are detectable only when
macOS refuses registration; this is not a complete inventory of shortcuts owned
by every app. Release each Raycast binding deliberately before enabling its new
owner. Changing an app binding does not re-register working controller groups.

A running app is activated without requesting a new window. Otherwise macOS opens
the selected app normally. App launching does not establish a layout, move windows
or restore app content. Applications search and launch shortcuts are not CLI
endpoints; existing Agent access remains separately controlled.

## Configurable shortcuts and Settings

Settings has General, Shortcuts, Applications, Layouts, About and Tiling tabs.
The Tiling page is present in the normal installed app. General uses
concise labelled switches. Shortcuts offers all 31 global commands in the seven
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

Import/Export/Last Report live in Settings → Layouts. Delete is available by its
library button, row context menu, Layout menu and Command+Delete. General contains Accessibility status and its settings link; About contains app/version diagnostics.
The library keeps Capture, Restore, Establish, Delete, Settings and Shortcuts; permanent
instruction footers and internal pilot labels are removed. Switcher grouping,
navigation and window-control primitives are unchanged.

## Stable build, installation and updates

The local app lives at `/Applications/Window Factory.app`. Native layouts
live at `~/.local/share/window-factory/layouts.json`. Build 32 migrated the
complete former `window-factory-native` directory, including installer backups. The separate
bundle ID `local.windowfactory.native` preserves preferences and Accessibility identity;
changing the data folder does not require changing that bundle ID. The first stable
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
library buttons display the main commands; the settings pane lists the full map:

| Command | Key |
| --- | --- |
| Keyboard Shortcuts | Tab + / (configurable in Library) |
| Capture | Command–N |
| Select layout | Up / Down |
| Move selected layout up / down | Option–Up / Option–Down, unfiltered list |
| Show / hide layout preview | Space, selected row; press again to hide |
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
- Search layouts/applications, select with arrows, preview normalized outlines
  in row thumbnails and the selected-layout pane; row icons identify saved apps;
  Return restores existing windows, Command–Return establishes missing ones,
  Escape cancels an operation/capture or closes the library. Double-click
  restores; Command–Delete requests confirmed deletion. Right-click a layout for
  Restore, Establish here or Delete; the menu targets the clicked row. Blank
  space has no layout context menu, and busy/capture states suppress it.
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

Default native data is `~/.local/share/window-factory/layouts.json`,
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


## Agent command-line access

General → Agent access enables the same-user CLI while Window Factory is running.
It supports status, capabilities, layouts/windows, Capture, Restore, Establish,
job results and cancellation without opening the UI. It reuses the existing
operation owners and store. The CLI cannot enable access itself. Agent access
remains enabled on this Mac at the owner's request after the successful Rex pilot.
See [CLI.md](CLI.md) for commands, structured results and recovery semantics.


## Development-output cleanup, 2026-10-25

The former `~/.cache/window-factory-native/build` directory and the obsolete
source-tree `.build/Window Factory Native.app`, `Bridge.o` and `adapters.json`
were moved to `~/.cache/window-factory/retired-development/2026-10-25/`.
Its `manifest.json` records exact original and archived paths for recovery.
Nothing was deleted; this is tidying, not reclaimed disk space. Current build
output remains `~/.cache/window-factory/build`; `.build` still holds active test
outputs and the original pilot catalogs. The geometry/Space pilot apps under
`~/.cache/window-factory-native` were running and were left in place.
Live catalogs, previous catalogs, installed app, settings, installer backups,
private temporary CLI receipts and Hammerspoon fallback remain untouched.


## Data-folder migration and backup builds (build 32)

The default store is `~/.local/share/window-factory`. Both the application and
installer use this path. Build 32 retains the exact bundle ID, signing identity,
preference domain and controls. An old default store causes startup to stop
rather than silently opening an empty catalog. The installer also refuses an
ordinary default install while legacy data exists.

For another installation that still uses the old folder, quit Window Factory
with no active operation or session stashes, then run:

```fish
mise run native-install -- --migrate-data-from /Users/troymay/.local/share/window-factory-native
```

Substitute that Mac's actual old directory. This explicit operation validates
both catalogs, rejects an occupied destination or symlink catalog/source,
renames the entire directory and restores its original location if app
replacement fails. The directory move never merges stores; after a successful
install, the backup retention policy below applies. Existing explicit
`--data-dir` launches keep their chosen location. For manual rollback to a
pre-32 app, launch it with `--data-dir` pointing at the migrated directory;
that old app's default still names the old folder. Do not let old and new apps
write the catalog simultaneously.

On this Mac, all 143 pre-migration file hashes matched after installation:
current/previous catalogs and all 35 backup app bundles were preserved. The
installer added build 31 as the 36th backup. All eight layouts were visible
after restart, app-owned settings hashes matched, strict signing checks passed,
and the live CLI reported Accessibility and Agent access still enabled. No
permission re-add, settings change, shortcut or fallback change was needed.
General Settings showed Start at login enabled; it was preserved, not changed
by migration, and a real sign-in startup check remains outstanding.

## Backup retention

Successful installs retain one backup for each of the two most recently backed-up
**distinct builds**. A build is identified by bundle ID, app version and build
number. Duplicate backups of the same build retain only the newest copy. The
installed app is separate from those two rollback copies.

Retention runs after the new app and any catalog copy have been verified and
the install transaction completed. It verifies both retained app signatures
before pruning, rejects unexpected entries/symlink backup directories, and uses
an exclusive maintenance lock. Finder's `.DS_Store` is preserved. A retention
failure is reported without rolling back an already successful installation.
Failed installs do not run retention. Layout catalogs, preferences, permissions,
the installed app and Hammerspoon are outside the pruning targets.

On 2026-10-25 the same retention operation reduced 36 backup bundles to builds
31 and 30, removing 34 older/duplicate bundles. Build 32 remained installed and
running. Catalog, settings and installed-binary hashes were unchanged; the live
CLI still reported Accessibility and Agent access enabled. No app restart or
new app build was needed for this installer-only change.

For inspection, `scripts/backup-retention.cjs --plan PATH_TO_INSTALL_BACKUPS`
reports its selection without changing it. `--apply` uses the identical guarded
maintenance path used by the installer. An interrupted run may leave a lock;
inspect the owning process before deliberately removing that lock. There is no
automatic lock stealing or age-based deletion.


## Disposable test-app cleanup and library actions (build 33)

On 2026-10-25 the owner requested quitting both disposable test apps and removing
their generated bundles. Window Control Test and Space Move Test quit normally;
their exact bundles under the former `~/.cache/window-factory-native/geometry-pilot`
and `space-pilot` directories were removed only after their processes exited.
`Tests/WindowControlPilot.swift` and `Tests/build-pilot.sh` remain available for
rebuilding. Existing saved recipes, including any test-app slots, are preserved.

The library now exposes a Delete button and row-specific Restore, Establish here
and Delete context actions. All use the existing guarded operation methods.
Deletion still asks for confirmation; the confirming action is explicitly named
Delete. Right-click selects the clicked row; a blank click cannot act on an old
selection. Deletion does not require Accessibility, but is disabled for no
selection, preview, capture naming and in-flight operations. The existing menu
and Command+Delete remain available. No geometry/focus/stash/switcher/accordion/
Space implementation or fallback changes are part of this UI change.


Build 33 passed the full native suite (209 AppKit assertions), repository
validation and strict installed-signature verification. The live row-menu test
changed selection from the pilot layout to Codex and opened confirmation naming
Codex; Cancel preserved it. The visible Delete button opened the same confirmation
and was also cancelled. Both current/previous catalog hashes and app-owned
settings hashes remained unchanged. The live CLI confirmed Accessibility and
Agent access remained enabled. No saved layout was deleted during verification.
The successful signed update retained only backup builds 32 and 31.


## Library row thumbnails and app icons (build 34)

Rows show a compact outline thumbnail drawn from the saved normalized window
frames, the layout name and up to four distinct app icons. The thumbnail is a
geometry illustration, not a live screenshot or a capture of application content.
App icons resolve by saved bundle ID through NSWorkspace without launching apps
and are cached for the library lifetime. Unavailable apps use a generic app icon.
Repeated windows in one app share an icon and show a saved-window count. Extra
apps appear as +N with their names available on hover. App icons have accessible
names/counts; the native row title and full summary tooltip remain available.

Row height is 68 points, with a fixed 84×52-point thumbnail, a truncating title
and a bounded icon strip. Search still matches saved names and app summaries;
selection, keyboard handling, double-click Restore and the row-targeted context
menu use their existing code paths. Layout schema, catalogs, operations, direct
controls and Hammerspoon fallback are unchanged.


Build 34 passed the full native suite (217 AppKit assertions), including grouping,
window counts, normalized thumbnail geometry, missing-icon fallback and bounded
many-app rows. Repository validation and strict installed-signature verification
passed. Live visual inspection confirmed the current saved rows, installed icons
and the Dual Finder ×2 count. App-name search found Dual Finder, clearing search
restored the full list, and right-clicking its icon selected that row and showed
the existing context actions; the menu was cancelled without executing them.
Current/previous catalog and app-owned settings hashes remained unchanged.


## Compact library, search ranking and manual order (builds 35–36)

The library defaults to a compact 620-point-wide list. Search, Capture and a
Preview toggle share the top bar. Settings, Keyboard Shortcuts and Delete use
accessible icon controls at the bottom, with Restore/Establish grouped on the
right. Tooltips retain the commands and configured shortcut hints. Empty status
and inactive capture-naming rows collapse rather than reserving footer space.
The Preview toggle persists and expands the library to show a read-only pane.
Both large and small previews fit the current display's usable-screen ratio;
they never stretch to fill arbitrary view bounds. Schema-v1 layouts do not
record capture-monitor aspect, so this is the current display ratio, not a claim
that old monitor metadata was recovered.

Search still includes layout names and saved app names. Results rank exact
layout-name matches first, then partial layout-name matches, then app-only
matches; manual order breaks ties before alphabetical fallback. Clearing search
restores the full manually ordered list. Unordered/new layouts append in name
order. The initial list remains alphabetical until a reorder is saved.

Drag a row above/below another row in the unfiltered list to save a manual order.
Only local, single-row moves within this table are accepted; external drags,
filtered results, preview mode, capture naming and in-flight operations cannot
reorder. An intervening list change invalidates a pending drag. Selection follows
the moved layout. Ordering persists under `layoutOrder.v1` in app preferences;
preview visibility uses `libraryPreviewShown`. Neither changes catalog bytes,
window geometry, adapter operations, the schema or CLI protocol. Exported
catalogs therefore contain recipes, not this Mac's presentation order.


Signed build 36 is installed. Full native tests passed with 231 AppKit assertions,
including search ranking, move indices, stale ordering, filtering/capture guards,
preference persistence and proportional preview geometry. A first socket-fixture
run failed its initial context assertion, passed in isolation, and both subsequent
full native runs (including the final build) passed all 41 agent assertions.
Repository validation and strict installed signature verification passed.

Live checks showed Rex first above its three app-only matches, the compact and
expanded views, correct aspect fitting, a row move through native dragging,
row-specific right-click actions, and preview/order persistence across restart.
The automation's drag coordinates targeted a different row than intended; the
owner's exact pre-test order was restored from its recorded preference while
the app was stopped, then verified on restart. Preview was returned to compact.
The final build fixes a title overlapping the shortcuts icon found in visual
inspection. Both catalog hashes and all prior app settings were unchanged;
only the new presentation preferences were written. No Restore, Establish,
Capture or Delete operation ran during these UI checks. Existing controller
source files, adapter operations and Hammerspoon fallback were unchanged.


## Library acceptance, drag grip and menu shortcut hints (build 37)

On 2026-10-25 the owner accepted name-ranked search, the preview toggle, manual
drag ordering and the improved compact layout, after accepting thumbnails/icons,
search and right-click in build 34 and Delete/right-click in build 33. These are
completed library features, not outstanding migrations.

Rows now show a native six-dot drag grip with an open-hand cursor. It is hidden
in filtered results, preview mode, capture naming and active operations. The grip
is an affordance for the existing native row drag; it does not implement another
reordering path or change keyboard selection.

The desktop badge menu shows native shortcut columns for Open Window Factory,
Settings, Keyboard Shortcuts and Quit. The two Library items read the shared
saved binding store, refresh on a successful Settings change/reset and refresh
again whenever the menu opens. Function/navigation keys use native menu glyphs.
Their tooltips also explain the configured Tab/Hyper chord. Settings remains
app-local Command-comma and Quit remains Command-Q. No extra global hotkey owner
or controller binding was added. The normal menu actions remain unchanged.


Build 37 passed the full native suite with 238 AppKit assertions, including
changed/reset Library bindings, native special-key equivalents and drag-grip
visibility. Repository validation and strict installed-signature verification
passed. Live visual inspection showed the six-dot grips; catalog and complete
app-settings hashes, including manual order and bindings, were unchanged after
restart. The live CLI reported Accessibility and Agent access enabled. The
controller implementations and Hammerspoon fallback remained unchanged.


## Keyboard ordering and Space Quick Look (build 39)

Option+Up/Down moves the selected layout one row through the existing saved-order
operation. Plain Up/Down still selects and now moves focus into the results
list. Selection stays with the moved layout and scrolls into view. First/last
boundaries are no-ops. Search filtering, capture naming, preview mode and active
operations disable reordering, as with dragging. The Layout menu exposes Move
Layout Up/Down and the shortcuts reference lists these fixed, app-local keys.
No global chord, controller or fallback binding is added or changed.

The owner replaced the persistent preview pane/button with a Quick Look-style
popover. Space shows it and Space again hides it; held-key autorepeat does not
flicker the toggle. Escape dismisses it first. Clicking outside uses normal
popover dismissal. The preview follows list selection and keeps the current
display's usable-screen ratio. Space in a nonempty search or capture name remains
text input; use Up/Down or click a result to focus the list before previewing.
When search is empty, Space can also preview the default selection immediately.

There is no Preview button or extra main-window hint. The shortcuts reference
includes Space. The popover is session-only; the obsolete `libraryPreviewShown`
preference is no longer read or written, but its stored value is preserved.
Recipe bytes and schema stay unchanged. The earlier build 35–36 pane behavior
above is retained as a dated implementation record, superseded by this section.


Build 39 is installed with strict signature verification. Full native tests
passed (251 AppKit assertions), including Option-arrow moves in both directions,
selection retention, plain-arrow selection, boundaries, filter/capture guards,
unchanged recipe bytes and persisted ordering. Repository validation passed.

Live checks moved Codex up with Option+Up and back with Option+Down, preserving
selection and restoring the exact original order. Space created the popover
and the next Space removed it. Selection could change with preview open. An
explicitly focused search accepted `Native desktop` including its space; Down
then Space previewed the filtered result and the next Space dismissed it. The
Layout menu showed both ordering commands with the unavailable upward move
disabled on the first row. There is no Preview button. No layout operation or
deletion ran. Both catalog hashes and the complete app-settings hash matched
before/after; Accessibility and Agent access stayed enabled. Existing window
controller implementations and Hammerspoon fallback were unchanged.
