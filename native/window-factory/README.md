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
| Agent CLI | Read-only/off-switch checks and live Rex Capture/Restore/Establish/repeat passed; see [CLI.md](CLI.md) |

Hammerspoon retains recoverable original implementations and Tab+Shift+R for
its library when running. The managed loader releases all seven direct-control
and indicator owners to Window Factory. Restoring a direct-control group still
requires releasing its native binding before enabling its Spoon fallback.
Karabiner owns hold-Tab → Hyper; Raycast owns app launching; macOS owns
Control+Left/Right. Those are separate integrations, not unfinished Spoon ports.
The canonical app-adapter definitions still live in Lua and generate bundled
JSON; the installed app does not require Hammerspoon to run.

Remaining verification and polish, before adding a new feature:

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
- Compare the old layout row thumbnails/app icons and right-click actions with
  the native list/selected preview. The old Restore/Establish/Delete context menu
  has not been ported; these operations are already available by buttons/menus/keys.

Deferred feature choices, with none selected by this review:

- **Custom geometries:** add user-defined size/position geometries later.
- **App launching:** an Applications shortcut group, app picker and launch/bring-
  forward actions; hand bindings over individually from Raycast after testing.
- **Binary-tree tiling:** KiwiDesk-style splits, sizing and reflow would be new
  layout behavior, not a missing accordion port.
- **Application state:** browser URLs, terminal commands and selected chats.
- **Coordinated animation:** presentation after reliable final placement.
- **Distribution:** notarization/updating beyond the current signed local installer.


Implementation and dated pilot receipts are preserved in
[development history](DEVELOPMENT.md); the [original transition plan](../../docs/native-window-factory.md)
is historical planning, not the current backlog.

## Configurable shortcuts and Settings

Settings has four tabs: General, Shortcuts, Layouts and About. General uses
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

Import/Export/Last Report moved to Settings → Layouts. Delete remains in the
Layout menu and Command+Delete. General contains Accessibility status and its settings link; About contains app/version diagnostics.
The library keeps Capture, Restore, Establish, Settings and Shortcuts; permanent
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
