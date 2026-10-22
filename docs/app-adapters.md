# Adding an application adapter

This is the shared maintainer/agent route for adding **Establish here** support.

The shared engine prepares apps sequentially and places each app's matching
windows once its creation phase ends, while preparing later apps. Launch and
creation discovery is scoped to the current app; all same-app slots are matched
together. Adapters should report command completion without adding placement
delays; the engine verifies window discovery and geometry separately.
Newly created or launch-discovered windows receive bounded startup placement
recovery: up to three placement cycles and two consecutive matching readbacks.
This handles observed startup geometry resets such as Rex's, without delaying
command completion, retrying creation, or changing existing-window/Restore timing.
Space, eligibility, and cancellation guards remain active throughout.
Rex additionally selects `placementPolicy = "position-only-when-sized"` in the
registry. For new windows already at their saved size, the shared frame helper
tries at most eight move-only requests with verified readbacks. A size mismatch
or exhausted moves returns to the original bounded frame recovery. Keep this
policy separate from creation completion; it neither delays nor retries the
native New Window command. Existing-window reuse and Restore ignore it.
Capture, Restore, and existing-window reuse already identify ordinary windows
generically. An adapter is needed only to launch an app or create missing
windows. See the [README](../README.md#factory-workspace) for user-facing behaviour
and the current app list.

## Where the behaviour lives

- [app_adapters.lua](../Hammerspoon/TheseusWorkspace.spoon/app_adapters.lua) is
  canonical for exact bundle identifiers, fixed commands/menu paths, and any
  installed-version requirements. One app means one registry entry.
- [window_factory.lua](../Hammerspoon/TheseusWorkspace.spoon/window_factory.lua)
  provides guarded, cancellable background launch and script/menu dispatch.
- [workspace_establish.lua](../Hammerspoon/TheseusWorkspace.spoon/workspace_establish.lua)
  counts launch-created windows, fills missing slots, and verifies new window
  identity, destination membership, and settled geometry.

Ordinary additions should change the registry and its tests, not these shared
engines. Scripts are fixed source; names and frames from recipes must never be
interpolated into executable commands.

Menu transport resolves the exact bundle with
`hs.application.applicationsForBundleID`, never a name/window-title fallback.
Before any command, an empty, invalid, or throwing application read may retry
up to three total attempts, with a 100-millisecond timer between failed reads.
Cancellation and destination guards cover the wait. Ambiguous or mismatched
identities fail closed. Once an app is resolved, neither menu resolution/lookup
nor selection is retried; one slot request still issues at most one native
New Window action. Diagnostics retain attempt numbers and candidate counts,
without raw native errors. This read recovery is separate from launch/discovery
waits and from placement recovery; do not turn it into command retries.

## Add one entry

1. Confirm the installed app's exact `CFBundleIdentifier` and version in
   `Contents/Info.plist`. Do not infer an identifier from a display name or alias
   a different app/release. For example, Microsoft's identifier is
   `com.microsoft.Powerpoint`, not `com.microsoft.PowerPoint`.
2. Inspect the installed scripting definition (`Contents/Resources/*.sdef`,
   including any referenced system definition), vendor documentation, or the
   exact enabled native menu. Establish that the operation creates an independent
   normal window, not a tab, template chooser, new chat, or content navigation.
3. Choose one of the existing entry types:

   ```lua
   ["com.example.Editor"] = {
     name = "Example Editor",
     kind = "applescript",
     script = [[
   tell application id "com.example.Editor"
     make new document
   end tell]],
   },
   ```

   This is a structural example, not a universal command. Use the app's verified
   creation API. `kind = "menu"` instead supplies `menu = { "File", "New Window" }`
   (the app's exact path). A reviewed app-specific `menu(app)` resolver may return
   an exact path from native menu metadata; shared dispatch still checks identity,
   enabled state, and the destination before selection. Safari reads only the File
   menu and selects the unique native default-profile marker (or ordinary New
   Window when profiles are absent). It never guesses a profile name or substitutes
   a tab, private window, AppleScript, or shortcut. `kind = "launch-only"` instead supplies a categorical
   `reason` and never creates additional windows. Ghostty illustrates the optional
   `checkInstalled(info)` metadata-only capability check.
4. Keep creation blank/default and unsaved. Do not reopen captured content, read
   documents or message data, activate an existing project window, select
   `window 1`, change launch/tab/template preferences, or add generic `Command + N`
   fallbacks. Rex Beta uses **File → New Window**, not **New Session** or
   **New Tab**; Ghostty remains a separate exact-identity adapter. Mail must create a **viewer**, never a compose/message window.
   Safari now uses the native default-profile File menu command, preserving normal
   startup-page settings and requiring only existing Accessibility access. An
   installed Safari 27.0.1 probe kept that new window on the selected empty Space
   while Safari was already running elsewhere; Codex and Rex menu commands passed
   the same condition. The default is resolved from the native identifier, not a
   stored profile name. Do not restore the failed blank-document route as a fallback.

   Historical Safari experiments below describe prior states, not the current
   adapter. Safari supplied `URL:"about:blank"` when making a new document. There
   was no focus workaround or added delay. Earlier trials on Safari 27.0.1 were
   complicated by computer state: restoring blank creation and restarting
   Hammerspoon did not resolve Space-switching failures until the owner rebooted
   the Mac. In the owner's normal workflow after that reboot, blank creation
   worked, bare `make new document` failed again, and explicitly opening
   `https://www.creativetension.co` also switched Spaces and was reported very
   slow. The real-page trial is withdrawn and blank creation restored. This
   implicates more than Safari's Start Page; the underlying mechanism remains
   unproven. Do not infer that a command works from a scripted pilot alone.
   A later two-stage experiment kept blank creation, added native ID receipts,
   and deferred page navigation until the complete layout was placed. The
   owner's normal Browsing test again switched from Space 6 to Space 3, created
   one visible Safari window, and was reported very slow. Its report stopped
   during `creating` with `active-space-changed`, zero verified new windows,
   zero placements, and zero page navigations. The deferred page stage never
   ran, so this failure cannot be attributed to page loading alone. The trial,
   including its extra creation identity checks and shared navigation lifecycle,
   was withdrawn; the simple blank-window baseline is restored. That rollback
   is not proof that the current desktop state has recovered.
   Test creation from a Space without Safari windows while another Space has
   Safari open. Do not change preferences or navigate existing windows.
5. If a new failure category is needed, add its friendly wording in `init.lua`
   and exercise it in tests. Do not expose raw app-returned errors or stderr.

## Verify without overstating coverage

Run `mise run validate`. Update:

- [app_adapters_spec.lua](../tests/app_adapters_spec.lua) for registry structure,
  supported catalog, exact identity, and intentional unsupported apps.
- [window_factory_spec.lua](../tests/window_factory_spec.lua) for the exact
  command/menu, background launch, safe failures, guards, and no fallback.
- [workspace_establish_spec.lua](../tests/workspace_establish_spec.lua) when the
  app introduces a different lifecycle. Its ordinary two-window cold-start and
  repeat-use cases exercise startup-window counting and other-Space protection.
- [tests/run.lua](../tests/run.lua) if adding a source or test file; it explicitly
  lists every Lua file to compile and every suite to run.

These tests do not execute AppleScript or create macOS windows. An installed
dictionary proves available terminology, not successful native behaviour.
After arranging a disposable pilot with the owner:

1. Use an empty ordinary Space and temporary, unsaved windows. Do not quit apps
   with project work; test a cold start only when the owner has left that app closed.
2. Establish two slots for the app. Confirm two independent eligible windows,
   the correct destination Space, settled frames, and a truthful completion report.
3. Repeat Establish; confirm reuse without duplicates. With an app window in
   another Space, confirm that window and its contents stay untouched.
4. Have the owner decide any Automation permissions. A prompt, app licence/login
   screen, chooser, disabled menu, or tab-only result is not a passing creation.
   Settle the issue and retry explicitly; never make the engine blindly retry.
5. Close only identified disposable windows; do not delete documents or recipes
   or quit an app as cleanup. Record app/version and scenarios actually tested
   in the handoff, distinguishing gaps from a successful native pilot.

If macOS/app tab preferences turn document creation into a tab, the engine reports
no new eligible window; it does not change preferences or count the command as
placement. English menu paths fail cleanly on unmatched localized releases.
Without a safe new-window operation, retain generic existing-window support;
add launch-only support only when its default-window behaviour is justified.

## Document and deploy

Update the README app summary, permissions and material limitations; leave
keyboard references alone unless a binding changes. Keep this guide current
when the extension procedure changes. Preserve existing recipes: ordinary adapter
additions need no schema change or recapture if their exact app IDs are unchanged.

Validate and review a scoped source diff, then deploy the **complete Spoon** through
the owner's configuration manager. A new registry module is required at runtime;
copying only `init.lua`/`window_factory.lua` is incomplete. Confirm source/live parity,
reload Hammerspoon, inspect load errors, and report checks, live coverage and the
local commit according to the host's policy. Reload alone is not a native pilot.

The registry and this guide are sufficient now. Consider a new shared transport
only if a real app cannot use scripting, an exact menu, or launch-only behaviour.
Dynamic plugins, arbitrary recipe commands, content restoration, and a generic
shortcut fallback are not part of this extension mechanism.
