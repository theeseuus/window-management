# Window Factory: Window and Workspace Management

Window Factory contains two independent components, implemented as Hammerspoon
Spoons:

- **Factory Window** provides deterministic macOS window placement, window
  switching, and native Space movement.
- **Factory Workspace** captures, restores, and establishes named,
  cross-application window layouts in the current native user Space.

The Spoon filenames and Lua API names are `TheseusWindow` for Factory Window
and `TheseusWorkspace` for Factory Workspace, as used in the installation and
code examples below.

## Hammerspoon baseline and native successor

The Hammerspoon recovery baseline is tagged `hammerspoon-baseline-2026-10-23`.
On 2026-10-23 the owner accepted production typing, navigation, Escape,
Capture/Cancel, and Establish of a new layout from a fresh capture after the
show-before-render rollback. The preceding two fresh creation runs and two
duplicate-free repeats remain the retained creation/reuse evidence. Restore
keeps its existing implementation; this latest owner check did not separately
exercise Restore. Rex startup placement can still visibly jump despite verified
final geometry. That known visual limitation is retained in the baseline.
Native macOS development follows from this recoverable Hammerspoon checkpoint.

The isolated [native Space helper proof](native/space-helper/README.md) records
standalone queries and disposable transfers of both helper-owned and separate
test-app windows, including a run without Accessibility trust. It is not
installed or connected to either Spoon.

The product's core is capturing the active applications and window layout and
restoring that workspace later. Recreating application contents, browser URLs,
or the selected chat is a later target. ScreenPlace and other installed window
managers are design references for the native work, not additions to this
baseline's feature scope. Coordinated animation is deferred during recovery.

Either Spoon can be installed and loaded without the other. The reference
configuration keeps broader responsibilities separate:

- Karabiner defines key semantics. Holding Tab emits Hyper
  (`Control + Option + Command`).
- Raycast owns the general application-launch shortcuts. Factory Workspace can
  launch supported apps only when filling missing saved-layout slots.
- Hammerspoon and these Spoons manipulate windows.
- Native macOS `Control + Left/Right` moves only the user between Spaces.

The complete reference map is in [SHORTCUTS.md](SHORTCUTS.md). Its application
launch shortcuts document one example setup and are not implemented by this
Spoon.


<img width="683" height="539" alt="image" src="https://github.com/user-attachments/assets/e12d8272-3242-4eeb-88b1-d5d87d7984c5" />




## Requirements

- For Factory Window move-and-follow, macOS with native Mission Control
  `Control + Left/Right` shortcuts enabled.
- Hammerspoon with Accessibility permission; version 1.1.1 is the tested
  release.
- At least two ordinary user Spaces for Factory Window move-and-follow commands.
- An ordinary user Space for Factory Workspace capture and restore. Full-screen
  and tiled Spaces are deliberately rejected.
- For **Establish here**, macOS Automation permission for each scripting adapter
  used (listed below). Ghostty requires version 1.3 or later with AppleScript
  enabled. ChatGPT and Mail use the existing Accessibility permission and
  require their exact, enabled new-window menus.
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
     workspaces = { { "ctrl", "alt", "cmd" }, "r" },
   }):start()
   ```

   Remove either block when that Spoon is not wanted. Factory Workspace does not
   load or call Factory Window internally. The Workspace binding shown here is
   the supplied reference map, not a hard-coded default. Copy the whole Spoon
   directory, including its local HTML and JavaScript panel assets.

3. Reload Hammerspoon and grant Accessibility access if macOS requests it.
4. Work through the manual integration checklist below before relying on live
   window or Space operations.

If dotfiles are managed by chezmoi or another configuration manager, add these
files to its source state and deploy them through that manager.

## Factory Window

Factory Window provides cross-app window switching, deterministic geometry
cycles in both directions, stateless canonical size and position cycles,
current-Space directional focus, stash/restore, accordion layout, a centred
half-width layout, position-preserving horizontal centering, maximize/minimize,
geometry restoration, width adjustments, and spatial arrow controls.

Directional focus collects current-Space windows only when its shortcut is
pressed, then releases the temporary window filter, including on collection
errors. It does not keep background application/window queries active between
commands. The menu-bar Space indicator remains event driven. An unresponsive
application can still delay a window-information request during a command.

## Factory Workspace

Factory Workspace treats the eligible windows in the current native user Space
as one cross-application layout. It supports:

- `Hyper + R`: open one compact **Window Factory** window for saved layouts and
  capture. Search by layout name or application, select a row, then use the
  bottom buttons, Return from search/the list for **Restore**, or `Command + Return` for
  **Establish here**. Double-click also restores; right-click or the row's
  actions button offers Restore, Establish, and Delete.
- **Capture…**: freeze the current workspace, then name and save that snapshot
  in the same window. Naming and Save stay disabled during capture. Saving
  returns to the library with the new recipe selected; Cancel returns without
  saving. An existing name requires explicit inline replacement confirmation.
- Live-generated outline previews for every recipe, drawn from saved normalized
  frames. Old and new recipes need no artwork or migration. Previews describe
  the saved layout, not the continuously changing desktop.
- Named recipe listing and direct deletion through the public Spoon API.
- Normalized geometry, so a recipe is restored relative to the current screen's
  usable frame rather than an old absolute pixel rectangle.
- Missing-window and extra-window reporting. Missing recipe slots are reported;
  extra windows are intentionally left untouched.
- Verified placement: wait for each frame to settle before counting it as
  placed, retry a quiet no-op, then try a separated resize/move if necessary.
  A request that still does not reach its saved frame is reported as failed,
  with the application named in the completion notice.
- Windows already at their saved geometry are verified without issuing another
  resize/move request. If they drift after matching, placement recovers them
  through the same bounded retries.

Capture includes normal, visible, non-minimized, non-full-screen windows that
belong exclusively to the current ordinary user Space and selected screen.
Sticky windows, panels, desktop elements, hidden/minimized windows, full-screen
windows, and windows on another screen are skipped. The current implementation
is intentionally single-monitor-first.

The capture view first shows **Capturing windows…**. Keep windows still until
it reports the captured count and enables the name field. You can then rearrange windows,
switch Spaces, or take your time naming the layout: Save uses only the frozen
snapshot, never another read of the live windows. Cancel or Escape discards the
unsaved snapshot and returns to the library; closing the window discards it too.
Repeating `Hyper + R` brings the existing panel forward rather than capturing
again. Opening the library does not itself capture any windows.

Capture and Restore use one application-window enumeration per operation instead
of a full scan for every window ID. Capture still reads macOS Accessibility
information sequentially; it is not an atomic screenshot of the entire desktop
at the instant the key is pressed. If the selected Space changes during
collection, capture fails without saving. The Window Factory panel itself is excluded.

The panel uses a native macOS window with system typography, automatic light/dark
appearance, and local-only assets. Its previews contain geometry and app names,
not screenshots. No web service or generated image is needed at runtime.
The native window is shown before the page applies its initial model, so page
focus is requested after native presentation. Repeating the entry shortcut
reuses that window. Content may draw after the frame appears. The prepared
hidden reveal was rolled back after a keyboard-input regression; the earlier
sequence passed the owner's harmless native-panel typing, arrow, and Escape
check on 2026-10-23. The subsequent production shortcut, Capture/Cancel, and
fresh-capture Establish checks also passed as recorded below.

Recipes identify a slot using the owning application's bundle identifier plus
an ordinal. They do not store window titles, document paths, browser URLs,
terminal working directories, or window contents. When an application has
several windows, existing windows are paired with its saved slots by proximity
to the normalized saved geometry. This preserves sensible placement without
claiming that Hammerspoon can recover the original document or tab identity.

**Restore** still reconciles only windows that already exist in the destination
Space. It never launches apps or creates windows.

**Establish here** reuses eligible windows already in the current Space, launches
supported apps if needed, and creates only the missing slots. The adapters are:

| App | New-window operation |
| --- | --- |
| Rex Beta | Exact **File → New Window** menu using existing Accessibility access |
| Ghostty | Native `new window` with a default surface configuration |
| Finder | Native `make new Finder window`, without a captured folder path |
| Safari | Native File menu command for the default profile; uses normal startup-page settings |
| BBEdit | Native `make new text window`, not a document added to an existing window |
| Chrome | Native new window; set only that new window's active tab to `about:blank` |
| ChatGPT / OpenAI desktop | Exact **File → New Window** menu, without activating an old window or substituting **New Chat** |
| Claude desktop | Launch-created main window and existing local-window reuse only; no verified additional-window command |
| Microsoft Excel | Native new unsaved workbook using the app's default |
| Microsoft Word | Native new unsaved document using the app's default |
| Microsoft PowerPoint | Native new unsaved presentation using the app's default |
| Keynote | Native new unsaved document using the app's default theme |
| Pages | Native new unsaved document using the app's default template |
| Numbers | Native new unsaved document using the app's default template |
| Mail | Exact **File → New Viewer Window** menu; never a new message/draft |

The six document-app adapters create default documents, not the files originally
open when captured. They do not change template or tab preferences. If an app
creates a tab or chooser instead of a new eligible window, Establish reports the
missing slot rather than changing preferences or accepting a false success.
Calendar and Preview have no automatic launch/creation adapter; their existing
eligible windows can still be captured, restored, and reused.

Exact app operations live in one `app_adapters.lua` registry; shared launch,
dispatch, Space checks, and verified placement remain separate. To extend it,
follow [Adding an application adapter](docs/app-adapters.md). The same guide is
linked from the agent entry point; ordinary additions need no new hotkeys,
recipe format, or plugin framework.

Rex Beta is identified exactly as `com.superlogical.rex`. It creates an
independent window through **File → New Window**, without enabling Rex remote
control or changing its Option-key handling. Ghostty remains supported separately.
Existing Ghostty recipes keep their identity; capture a layout containing Rex
windows when that layout should use Rex.

A 2026-10-22 pilot with Rex Beta 0.1.0 (1347) invoked the deployed menu adapter
and observed exactly one new standard window in the destination Space. Rex
also exposed one non-standard auxiliary window; existing eligibility filtering
excludes it. The disposable standard window was closed afterward. A subsequent
live pilot used the deployed Capture/Establish APIs with Rex already running:
two Rex-only slots on an owner-selected empty Space, then one window closed.
The first Establish placed two, created one replacement, and reused one; the
repeat placed two, created none, and reused both with unchanged window IDs.
Both reports had zero missing slots, extras, placement failures, and creation
failures. Existing Rex geometry/Space membership and prior recipes were
preserved. Disposable windows were closed; the test recipe was retained in
application-owned state. Cold-start and safe failure cases remain mock-only
coverage; this pilot does not prove cold-launch or reboot recovery.

An owner-driven normal-interface retest with the Hammerspoon Console hidden
also passed: the first Establish created/placed two Rex windows, and the
repeat created none and reused the same two IDs. Both completed on the selected
Space without failures; the owner confirmed the visible result. An earlier UI
attempt stopped before creation with `active-space-changed`; the Console's
possible role in that transition remains unproven. The owner reported slow
initial panel drawing while diagnostic focus/Space polling was active. A later
baseline confirmed those recurring timers were stopped: opening returned in
0.033 seconds, the page was ready without a render error at a single two-second
check, and the owner reported a prompt appearance, roughly under a second.
The delay did not reproduce in that baseline. Polling is a possible contributor,
not a proven cause; no opening-path code change was required. Timing used only
one-shot callbacks, with no new recurring observer.

Safari resolves the default profile's native new-window command from the File
menu's Accessibility identifier; it does not store or guess profile names.
Without profiles it accepts the ordinary native New Window command. An absent,
ambiguous, or disabled command fails cleanly, without another profile, a tab,
AppleScript, or a keyboard fallback. This uses existing Accessibility access and
leaves Safari's profile, startup-page, pinned-tab, and tab preferences unchanged.
It creates a normal default-profile window rather than forcing `about:blank`.

A 2026-10-22 GPT Workspace failure stopped with `active-space-changed` before any
new window was verified. Safari was first in the three-app recipe (Safari,
Codex, Rex). With all three apps already running elsewhere, an isolated native
menu probe created one independent window per app in the selected empty Space,
without switching Spaces, and closed only those test windows. Safari 27.0.1,
Codex 26.1013.40934, and Rex 0.1.0 (1347) were tested. The profile-aware Safari
resolver was also checked against the installed menu. The subsequent normal-UI
GPT Workspace test stayed on the selected Space: first run created all three
windows with no missing slots or extras; Safari and Codex placed correctly but
Rex reported `frame-not-restored`. The repeat created none, reused the same three
window IDs, and placed all three without failures. The windows were left open,
the saved catalog was unchanged, and the temporary observer stopped. This fixes
the tested Space-switching failure and exposed Rex's first-run placement issue.
Cold-launch/reboot behavior is not established by this running-app test.

Establish marks only windows it created or discovered from its app launch as
new. Those windows require two consecutive matching frame readbacks and can
use up to three bounded placement-recovery cycles, retaining all Space,
eligibility, and cancellation guards. Existing-window placement and Restore
keep their original timing. Recovery never launches or creates another window.

New Rex windows use a registry-selected move-only path when a fresh frame read
already matches the saved width and height. It avoids redundant resize requests,
checks each move, and requires two consecutive complete-frame matches. After at
most eight move requests, or if the size differs/reverts, the original bounded
frame recovery takes over. Existing windows, Restore, and other apps retain
their previous placement path; Safari keeps its normal startup window.

A follow-up Rex 0.1.0 (1347) trace on an empty Space accepted each position write,
then reverted to startup geometry for about two seconds. The original one-second
placement cycle reported failure; later placement held and remained correct at
an additional check. Startup recovery handles this lifecycle inside one Establish
operation, with no unconditional delay in the window-creation adapter. Safari's
native default-profile startup-window command is unchanged.
The full-layout acceptance attempt after deployment stopped with
`active-space-changed` before any new window or placement was verified, so it did
not exercise Rex's updated startup recovery. The temporary observer restored the
original method and stopped its timers. At that pre-reboot checkpoint, first-run
native acceptance remained pending; automated tests were not that proof.

In the owner's 2026-10-23 post-reboot normal-UI test, the first Establish stayed
in the selected empty Space and opened correctly positioned Safari and Rex
windows; Safari retained its normal default-profile startup behavior. GPT/Codex
was absent. The repeat added that window without duplicating the others. Its
retained report confirmed three placed, one created, two reused, zero missing,
zero placement/creation failures, zero extras, and no stop reason. This accepts
first-run Rex placement for the observed scenario and verifies repeat recovery;
complete first-run GPT Workspace creation still failed.

The first run's report was overwritten by the repeat, so its exact failure
reason is unavailable. The owner reported slow response after Command–Return;
no start/end or per-stage timings were retained, so duration and cause remain
unmeasured. The next diagnostic should preserve the first failure and measure
bounded action-to-feedback, creation, and placement stages without recurring
window polling. Installed versions were Safari 27.0.1 (22625.1.29.11.28), Codex
26.1016.51333 (21161), and Rex 0.1.0 (1347). Codex had updated since the earlier
probe; that is compatibility context, not an established cause. The inspection
changed no application configuration, recipes, or windows.

The next instrumented normal-UI first run on 2026-10-23 retained its full report:
three requested, two created/placed, zero reused, one missing Codex slot, no
placement failures or extras, and no Space-stop reason. Codex failed during
application lookup with `application-not-running`, before any menu lookup or
selection. The original diagnostic merged a lookup exception with an absent
app; it does not establish that Codex quit. The recipe's “ChatGPT” display label
still targeted the exact `com.openai.codex` bundle.

Measured action-receipt-to-completion time was 5.805 seconds with no dropped
events. Destination-context resolution before closing the panel took 1.506
seconds; initial feedback began at 1.521 seconds. The failed Codex application
lookup took 1.141 seconds. Rex placement verification took 2.085 seconds and
succeeded; the owner observed the window moving back and forth before settling.
These are wall-clock stage intervals, not isolated app startup costs. Safari's
1.464-second placement interval overlapped the synchronous Codex lookup, which
may delay scheduled verification callbacks. Do not add overlapping stage totals.
The context stage still combines several native calls, so its internal cause
is unmeasured.

A subsequent bounded read-only probe found one running GUI Codex instance and
three successful lookups, each below one millisecond. The immediate failure is
therefore isolated to the earlier application lookup, but its native cause and
any connection to the Codex update or removed Dock item remain unproven. Future
diagnostics distinguish `application-lookup-failed` (exception) from
`application-not-running` (no object), retain lookup outcome/type flags, and
separate absent apps from apps exposing zero windows in enumeration. This
refines reporting without adding calls, retries, or a new creation operation.


A later normal-UI creation run in the same diagnostic session created and
placed all three windows from scratch (`created=3`, `reused=0`) in 4.380 seconds.
The repeat placed the same three window IDs, created none, and reused all three
in 1.861 seconds. Both had zero missing slots, creation/placement failures,
extras, stop reasons, or dropped events. Codex's successful lookup took 0.424
milliseconds; its enabled New Window menu was selected successfully, and the
new window was observed on the first discovery check. This verifies the tested
fresh creation and repeat without duplicates, while retaining the earlier
intermittent lookup failure as unresolved. Rex still moved visibly during
startup placement; verification took 1.817 seconds in the creation run and
0.257 seconds when reused. These are verification intervals, not pure app
startup measurements.

All three attempts spent 1.506–1.511 seconds resolving context before initial
feedback. A bounded read-only call-level probe isolated `hs.window.focusedWindow()`:
it returned nil after 1.502 seconds; main-screen lookup and subsequent Space,
Space-type, and screen-frame reads took milliseconds or less. Codex was the
frontmost application in that probe; the underlying Accessibility timeout/cause
is not established. Live panel actions now select their screen from the native
webview frame, then read the active ordinary Space and screen frame afresh.
Capture, Restore, Establish, and refreshing an existing panel avoid the focused
app query; opening the first panel and direct non-panel APIs retain their
previous screen-selection path. A missing panel screen fails explicitly, with
no focused-app fallback. This neither caches a Space nor weakens operation
Space guards; no app activation, retry, creation, or Rex-placement behavior
changes are involved.

After deployment/reload, a native panel-action probe exercised the production
context and close path, intercepting the final Establish call before any
workspace operation. Context resolution took 3.517 milliseconds and panel
dispatch/close took 10.882 milliseconds, with the resolved Space still active.
The original method was restored; no workspace windows, recipes, or app
preferences changed and no operation remained running. This verifies the
latency improvement in that path, not a full post-fix Establish timing. The
successful fresh creation and duplicate check above preceded this context fix.

A subsequent normal-UI repeat on 2026-10-23 confirmed prompt feedback and a
correct unchanged layout. The retained report placed all three existing windows,
created none, and reused all three in 0.345 seconds, without missing slots,
failures, extras, or dropped events. Panel context took 1.730 milliseconds,
dispatch/close took 5.832 milliseconds, and initial feedback began 9.892
milliseconds after Lua received the action. This accepts the initial-pause fix
for that normal UI path; it does not measure a fresh app launch.

Bounded disposable Rex 0.1.0 (1347) traces reproduced the old path using four
full-frame requests plus a resize and a move before verification at 2.099
seconds. A move-only trace of the saved GPT slot, whose initial size was already
correct, reached the target at 1.298 seconds and verified the next matching
read at 1.556 seconds without a resize or full-frame request. Single combined
or move requests, including a delayed move, did not hold in the observed
intervals. Separate changed-size experiments still reverted when moved, so
those frames retain the original recovery. These observations justify the
narrow move-only path; the native cause and visual smoothness remain separate
from geometry verification. Every identified disposable window was closed.

After managed promotion and reload, the deployed policy placed another
independent disposable Rex window in the saved slot, verifying at 1.561 seconds
with zero full-frame requests, zero resizes, five position requests, and seven
frame reads. The frame still matched half a second later; only that identified
test window was closed. This is native geometry acceptance of the deployed
helper, with normal-UI visual acceptance checked separately.

The next normal-UI first run on 2026-10-23 still missed Codex and the owner
still saw Rex jump. Its retained report created/placed Safari and Rex only,
with one missing Codex slot and no placement failures, extras, or Space stop.
Total time was 2.676 seconds; panel context took 3.211 milliseconds and initial
feedback began at 11.321 milliseconds, so the earlier initial pause remained
resolved in this run. Codex was reported running, but the menu's separate
application lookup returned nil about 11 milliseconds later. No Codex menu was
looked up or selected. That lookup path was unchanged from the previously
successful version and failed before Rex placement started; the evidence
supports recurrence of the earlier intermittent lookup failure, not attribution
to the latest Rex change. It does not establish the native cause.

Rex used the intended move-only path: five position requests, zero size/full
frame requests, seven reads, and verified geometry in 1.601 seconds. This did
not pass visual acceptance. The repeat added Codex and reused the same Safari
and Rex windows in 0.801 seconds, with zero missing slots, failures, extras,
or Space stop. Codex's lookup then took 0.422 milliseconds and its genuine
menu command succeeded. Versions were Codex 26.1016.51333 (21161), Rex 0.1.0
(1347), and Safari 27.0.1. Coordinated animation remains deferred until first-run
creation and placement are accepted; it is not a remedy for failed discovery.

Menu dispatch now looks up only the exact bundle identifier, avoiding generic
name/window-title search when a native read is empty. An empty, invalid, or
throwing lookup gets at most three read attempts, separated by 100 milliseconds
only after failed reads. Multiple candidates or a mismatched identity stop
without selection. Space and cancellation guards remain active. Menu resolution,
lookup, and selection are never retried; at most one New Window command is
issued. Exhausted empty reads report that the app could not be located, without
asserting that it quit. The timeline records each attempt and candidate count.
The regression suite reproduces a running Codex instance missed at menu lookup,
then verifies recovery within the first Establish, repeat reuse, and other-Space
protection. Safari's native default-profile command and Rex placement are
unchanged. A native read-only check found one exact instance of each app;
post-fix normal-UI creation acceptance remains pending.

Subsequent pointer-driven tests on 2026-10-23 produced two successful fresh
Establish runs (three created/placed windows each, 2.703 and 2.725 seconds) and
two successful repeats (zero created, three reused, 0.353 and 0.348 seconds).
All four reports had no missing slots, extras, placement failures, or creation
failures. One fresh run recovered an empty Codex application lookup on its
second read about 104 milliseconds later, within that same Establish. Versions
were Codex 26.1016.51333 (21161), Rex 0.1.0 (1347), and Safari 27.0.1.
The owner still observed Rex jumping. The owner also reported that keyboard
navigation and shortcuts failed, including typing after clicking search, so
these results accept creation/reuse through the pointer path only. A harmless
memory-only panel pilot is comparing the earlier presentation sequence with
the prepared-content reveal; no keyboard fix or native successor is accepted
by these creation reports.

The owner then tested the memory-only panel using the presentation sequence
from before `aadb284`, with the later destination-frame accessor retained.
Typing after clicking search, Up/Down navigation, and Escape all worked. The
prepared-content reveal has therefore been rolled back as one isolated change;
no application adapter, creation command, placement rule, or shortcut changed.
This comparison implicates the presentation lifecycle but does not establish
the underlying AppKit/WebKit focus mechanism. The production shortcut and full
workspace acceptance must pass before a baseline tag is created.

After deployment and reload of the rollback, the owner confirmed through the
normal Window Factory path that typing, navigation, Escape, Capture/Cancel,
and Establish of a new layout from a fresh capture all worked. This is the
2026-10-23 operational acceptance for the Hammerspoon baseline tag above.
The latest confirmation did not include a separate Restore or duplicate test;
the unchanged creation/placement engine retains the earlier repeat evidence.
No application contents were captured or recreated, and the observed Rex
startup jumping remains a known limitation rather than accepted smoothness.

The OpenAI desktop adapter recognizes `com.openai.chat` and `com.openai.codex`,
but only invokes the genuine New Window menu in the exact app identified by the
recipe. A missing/disabled menu fails cleanly. Older releases that offer only
New Chat are not assumed to create independent windows. Bundle identifiers are
not aliases: after changing desktop-app variants, recapture the layout if it
should use the new app instead of the previously captured one.

The inspected Claude desktop release exposes **New Chat**, not **New Window**.
Establish can launch Claude if closed and place a main window that appears in
the current Space, or reuse an eligible Claude window already here. It cannot
safely create an additional independent Claude window while another is open on
another Space. Missing Claude slots are reported explicitly; no New Chat, deep
link, second process, or existing-window movement is used as a fallback.

Windows belonging to other Spaces, other screens, or excluded apps are never
borrowed. Unsupported apps can still have their existing local windows placed;
their missing slots are reported without a generic `Command + N` fallback.
Discovery is scoped to the apps named in the recipe. Its extra-window count
therefore covers those apps, not unrelated apps elsewhere on the desktop.
During launch and creation, discovery checks only the app currently being
prepared, avoiding repeated inspection of the other recipe apps.

Establish allows up to about 15 seconds for a cold launch and observes stable
launch-created windows before asking for more. Each explicit
creation must produce one new eligible window exclusively in the destination
Space. Once an app's creation phase ends, its eligible matching windows are
placed while subsequent apps are prepared, rather than waiting for the final
app. Same-app slots are matched together before placement. All matching frames
must settle before they count as placed. A
successful script alone is not proof of creation or placement. Repeat Establish
after a successful run to reapply geometry without creating duplicate windows.
Keep the destination Space selected and avoid opening or closing target-app
windows until the completion notice. Ambiguous creations are left untouched.

macOS may ask to let Hammerspoon control each app on first use. Approve only the
access you want. A command can time out while the prompt awaits your decision;
settle the permission and inspect any new windows before explicitly trying again.
Denied, unavailable, wrong-Space, and timed-out creation is reported, never
automatically retried. Switching Spaces or stopping the Spoon cancels further
work, but does not close windows already created. Native app launch/session
preferences may themselves reopen windows; this Spoon does not change those
preferences or recover contents.

Factory Workspace does **not yet** track live group membership, move a group
between Spaces, create or remove Spaces, continuously enforce a layout, or
restore browser tabs, Finder folders, terminal commands, or chats.

Recipes are stored under the Hammerspoon settings key
`TheseusWorkspaceRecipesV1`, outside this Git repository. To remove an old
layout, open `Hyper + R`, highlight it and press `Command + Delete`, or
right-click its row and choose **Delete saved layout…**. The confirmation names
the exact layout and defaults to Cancel. Only explicit Delete removes the saved
recipe; no windows, applications, or Spaces are moved, closed, or deleted. The
library refreshes afterward, retaining its search; deleting the final layout
leaves an empty library with Capture available. There is no undo. `Command + Delete`
and `Command + Return` are handled only while the library has keyboard focus,
not as global shortcuts. Delete and replacement confirmations stay in the same
window and refuse to act if the target recipe has changed since confirmation
opened.

The public API can also be used directly from the Hammerspoon Console:

```lua
spoon.TheseusWorkspace:showWorkspaces()
spoon.TheseusWorkspace:captureCurrentWorkspace("Project Atlas")
spoon.TheseusWorkspace:captureCurrentWorkspace("Project Atlas", { replace = true })
spoon.TheseusWorkspace:restoreWorkspace("Project Atlas")
spoon.TheseusWorkspace:establishWorkspace("Project Atlas")
spoon.TheseusWorkspace:listWorkspaces()
spoon.TheseusWorkspace:deleteWorkspace("Project Atlas")
```

The direct `deleteWorkspace` API deletes immediately, without the panel's
confirmation; callers are responsible for confirming their target.

Establish diagnostics are memory-only and reset when Hammerspoon reloads.
`firstEstablishReport` pins the first non-busy API attempt after reload, while
`establishReports` retains the ten most recent reports in chronological order;
`lastEstablishReport` remains the latest. Each report has an `attempt` number
and `diagnostics` with a UTC start label, monotonic `durationSeconds`, bounded
`events` (512 maximum, with `droppedEvents`), and per-stage/per-app `totals`.
Invalid recipe/context attempts are retained as `phase="rejected"`; busy
requests still return their existing error without starting another attempt.

Timing begins when Lua receives the panel action (or at direct API entry), not
at the physical keypress. Stages cover panel dispatch/context/close, preparation,
feedback calls, Space guards, window collection per app, capability checks,
launch/creation dispatch, native menu resolution/lookup/selection, discovery
waits, and verified placement. Placement events also count full-frame, size, and
position requests plus frame checks, so successful recovery can be distinguished
from repeated geometry writes. Nested and concurrent timings overlap: do not
sum them to obtain total elapsed time. Enumerations retain observed/eligible
counts and categorical skip reasons, never window titles, contents, or raw app
errors. No extra window scans, recurring observers, creation retries, recipe
writes, or application preference changes are introduced. Existing bounded
creation/discovery and placement checks remain authoritative.

For a first-run diagnostic, reload, run Establish once from an empty ordinary
Space, then inspect `spoon.TheseusWorkspace.firstEstablishReport` before any
repeat. A repeat remains separately inspectable in `establishReports`. The
history is not saved to disk; export only a deliberately scoped report when
needed. This measures the command's work, not when macOS paints an alert.


`establishWorkspace` is asynchronous and accepts `silent` and `onComplete`
options, like Restore. Its final report is held in `lastEstablishReport` and
includes verified `applied`, `created`, and `reused` counts, `missing`, `extras`,
placement `failures`, and categorical `creationFailures`. `pending`, `phase`,
and `finished` describe progress; `reason`/`cancelled` describe an interrupted
operation. These reports are memory-only. Restore and Establish reject
overlapping operations and never rewrite the saved recipe.

The direct `captureCurrentWorkspace` API captures and saves synchronously when
called; the panel uses the non-blocking capture/name/save flow. Both store
the same recipe schema, so existing recipes remain compatible.

For existing custom configurations, `showRestoreChooser()` opens Window Factory and
`promptCaptureCurrentWorkspace()` opens its capture view. The legacy `restore`
and `capture` hotkey mappings are still accepted when explicitly configured;
the reference setup now uses only `workspaces` on `Hyper + R` and no longer
assigns `Hyper + Shift + R`.

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
Viewer. Factory Window reserves that binding for upward focus, so remove or
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

The supplied `Hammerspoon/init.lua` enables a compact menu-bar indicator with
the Space number centred inside a rounded rectangular outline:

```lua
spoon.TheseusWindow.showSpaceIndicator = true
spoon.TheseusWindow:bindHotkeys():start()
```

Set `showSpaceIndicator` to `false` to disable it. The indicator has no hotkeys
and performs no Space switching. Each `hs.spaces.watcher` notification triggers
an immediate update, followed by a settling check 100 ms after the last
notification. Rapid traversal does not postpone the immediate updates. The
label is recomputed from the ordered list of user Spaces rather than displaying
an opaque macOS Space ID. The outline and number are rendered as a monochrome
template icon, letting macOS choose their colour. The interior and surrounding
area are transparent, so the menu-bar wallpaper remains visible. The icon is
24 × 18 points for one or two digits, widening for larger numbers. An unavailable
Space shows `?` inside the outline; a full-screen/tiled Space shows `—`.

## Security and privacy

Factory Window runs locally and makes no network requests. It contains no
telemetry, credentials, account identifiers, or persistent logging of window
titles and frames.

Factory Workspace also runs locally and makes no network requests. It persists
the user-supplied workspace name, capture timestamp, application names and
bundle identifiers, per-application slot ordinals, and normalized window
geometry through `hs.settings`. It deliberately does not inspect or persist
window titles, paths, URLs, terminal working directories, or document content.
Recipes are local runtime data and are not stored in this public repository.
Establish uses fixed, allowlisted native app scripts and exact new-window menu
paths; recipe names, application names, and captured content are never
interpolated into executable scripts or selected as menus.
macOS app Automation access is broader than just window placement. Review the
source before granting it. The adapters neither read contents nor send terminal
input, and do not change app launch/session preferences.

Hammerspoon's Accessibility permission is powerful: it allows these Spoons to
inspect and manipulate windows and allows Factory Window to synthesize mouse and
keyboard events.
The native Space transport briefly moves the pointer to the focused window's
title bar, holds that window, emits `Control + Left/Right`, releases the window,
and restores the pointer. Review the source before granting Accessibility
permission and install only code from a revision you trust.

## macOS and Hammerspoon limitations

- [`hs.spaces`](https://www.hammerspoon.org/docs/hs.spaces.html) is experimental
  and uses private APIs. Factory Window still relies on it to enumerate and
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
  Factory Window reapplies the original frame, but macOS and the application
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

The repository pins Lua 5.4.8 and Node 24.19.0 in `mise.toml`. Node is used only
to check the local panel script and run dependency-free JavaScript tests; it is
not needed by Hammerspoon at runtime. You may also run
`./scripts/validate.sh` directly after installation, or set
`VALIDATION_LUA_BIN` to a compatible Lua executable.

The script compiles all Lua files, checks JavaScript syntax, and runs pure tests for ordered user-Space
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

Unified-panel capture tests cover disabled naming/Save until readiness, one window
enumeration, moves and screen changes after readiness, frozen geometry across
replacement confirmation and save retries, catalog changes while naming,
cancel/close/stop cleanup, Space changes during collection, and failed discovery.
The frame-copy regression deliberately moves Ghostty's mocked geometry after
capture and confirms that Save retains the original coordinates.

Panel tests cover recipe-derived previews, filtering by name/application,
selection, safe text handling, named inline confirmations, preserved search,
changed confirmation targets, stale/closed-view events, save failures, empty
libraries, and close/stop cleanup. Delete never enumerates windows or changes
Spaces. Restore and Establish retain the intended destination before closing
the panel; only the configured global entry shortcut is registered. In-memory
catalogs and mocked bridges exercise these workflows without changing user data.

For a safe native interface pilot, run
`dofile("/absolute/repo/path/tests/manual_panel_pilot.lua")` in the Hammerspoon
Console. It uses synthetic capture records, an in-memory catalog, and print-only
Restore/Establish receipts. Save, replace, and delete do not touch real recipes;
no app windows are created or moved. Close its window, then run
`workspacePanelPilot = nil` when finished. The pilot deliberately does not bind
any keyboard shortcut or prove live application placement.

Establish tests cover existing-window reuse, exact missing-window counts,
repeat-use idempotency, delayed cold-launch default windows, launch-only apps,
genuine new-window menus, missing/disabled menus, exact app identity, unsupported and
excluded apps, denied automation, wrong-Space and ambiguous creations, bounded
waits, safe categorical errors, cancellation, and verified placement. They
also verify scoped app discovery, untouched other-Space windows, mutual
exclusion with Restore and no settings writes. Native panel interaction and
visual evidence are recorded separately in [design-qa.md](design-qa.md).
Adapter tests check every registry entry and each fixed command/menu, including
the Office/iWork adapters, Mail viewer-only behaviour, and explicit unsupported
Calendar/Preview creation. Mocked cold starts exercise two-window startup counting
and repeat-use idempotency for each new app; these are not native app pilots.

The separated resize/move fallback was informed by Hammerspoon's
[frame-setting timing discussion](https://github.com/Hammerspoon/hammerspoon/issues/3731).
It uses non-blocking timers and verifies the outcome; no code from that
discussion was copied.

Validation levels are intentionally distinct:

- **Syntax:** every Lua file compiles and the panel JavaScript parses.
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
- [ ] In an ordinary project Space, press `Hyper + R`; confirm one compact
      library opens with a layout outline, name, count, and separated app summary
      for each recipe. Search by name and app; use the arrow keys to select.
- [ ] Choose **Capture…**; confirm the same window shows **Capturing windows…**
      with naming and Save disabled until the captured count appears. Name/save
      the layout, then confirm the library selects it and its preview matches
      the saved window geometry.
- [ ] Once the snapshot is ready but before saving, move a captured window.
      Save, then restore the recipe; confirm the window returns to the position
      from before naming, not the moved position. Repeat with replacement
      confirmation and verify it still uses the original snapshot.
- [ ] Cancel a capturing or ready view with its button or Escape; confirm it
      returns to the library without saving. Close the window and repeat
      `Hyper + R` while capturing; confirm no unsaved recipe is persisted and
      no second window or snapshot is created.
- [ ] Move and resize those windows, press `Hyper + R`, select the recipe and
      press Return (or double-click it), and
      confirm all matching windows return to their captured relative frames,
      including background Ghostty windows. Wait for the verified completion
      notice; if any app is named as failed, inspect `lastRestoreReport`.
- [ ] Capture the same name again and confirm replacement requires an explicit
      confirmation rather than silently overwriting the recipe.
- [ ] In `Hyper + R`, highlight a disposable recipe and press `Command + Delete`.
      Confirm the inline view names it and defaults to Cancel. Cancel and verify the
      recipe and search are unchanged; then explicitly Delete it and verify
      only that recipe disappears, without moving or closing any windows.
- [ ] Repeat deletion from the right-click menu while filtering the library.
      Confirm the visible row is the named target, other recipes survive, and
      deleting the last recipe leaves an empty library ready for Capture. Outside the panel,
      `Command + Delete` must retain its normal application behavior.
- [ ] Close one captured application window, restore the recipe, and confirm the
      result reports one missing slot without moving an unrelated replacement.
- [ ] In an empty ordinary Space, use `Hyper + R`, highlight a layout, and press
      `Command + Return`, click **Establish here**, or right-click and choose
      **Establish here**. Settle any requested app Automation permission, then
      retry explicitly if the first command timed out. Verify only supported
      missing slots get new windows, no other project windows are moved, and
      `lastEstablishReport` confirms settled frames and destination membership.
- [ ] Include two ChatGPT windows, two BBEdit windows, and two Chrome windows.
      Confirm each missing slot becomes a separate window, not a tab, document,
      or replacement chat. Chrome's new tabs should be blank; existing browser
      tabs, chats, and text documents must remain unchanged.
- [ ] Pilot Excel, Word, PowerPoint, Keynote, Pages, and Numbers with two
      disposable unsaved documents per app. Confirm separate normal windows,
      not tabs or a template chooser; no captured files are reopened. Pilot Mail
      with two viewer windows and confirm no draft/message is created. Keep
      another window of the app in a different Space and verify it is untouched.
- [ ] With an app that can safely be closed already quit by the owner, Establish
      its layout. Confirm startup windows are counted before requesting extras;
      repeat after success and confirm no duplicate windows. App-controlled
      session restoration may reopen windows elsewhere; those stay untouched.
- [ ] For Claude, verify reuse of a local window and launch from closed with a
      one-window recipe. If Claude is already running elsewhere, or another
      independent window is needed, confirm an explicit missing-slot notice
      instead of changing that other window or its chat.
- [ ] Establish the same layout again; confirm no new windows are created.
      Leave an extra window and include an unsupported app to check extra/missing
      reporting. Switch Spaces during an operation and confirm further work
      stops without closing already-created windows. Outside the panel,
      `Command + Return` must retain its normal application behavior.
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
