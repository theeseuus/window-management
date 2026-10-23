# Standalone native Space helper proof

This isolated Objective-C executable tests whether a native companion can retain
Space information without depending on Lua or installing Hammerspoon 2. It is
not integrated into either production Spoon and is not installed or started at
login. There is no background polling or persistent helper process.

## Initial C-API proof on this Mac, 2026-10-23

Environment: Apple Silicon, macOS 27.0.1 build 26A434, Hammerspoon 1.1.1,
Xcode macOS SDK 27.0, Apple clang 21.0.0 (clang-2100.3.34.2).

| Proof | Observed result |
| --- | --- |
| Native read-only query | One display, seven ordinary Spaces; ordered topology, types and current Space matched Hammerspoon. |
| Window membership comparison | Exact membership matched for five standard windows. All 104 window-ID entries in Hammerspoon's per-Space lists appeared in the raw native lists. Hammerspoon filters some canvas IDs from its own output. |
| Modern compatibility-workspace protocol | Preliminary `SLSSpaceSetCompatID` call returned unexpected status 1834979; no window move request was sent. The disposable window closed. This exploratory implementation is not retained. |
| Direct `SLSMoveWindowsToManagedSpace` | One request moved the helper-owned disposable window from user Space 6 to adjacent user Space 7. Two consecutive readbacks reported only the destination. Completed in about 0.87 seconds including window creation and cleanup. |
| Cleanup and isolation | Active Space remained 6. A separate post-exit query returned no membership for the closed test window. Production Hammerspoon files were not changed or reloaded. |

**Initial conclusion:** native queries and moving a caller-owned window work here.
At this stage, moving another application's window remained unproven. The
WMBridge investigation below extends that result. These results do not
establish that a native helper can replace the existing drag-and-key transport
in TheseusWindow, nor that the private move API fixes Rex startup placement.
Actual Hammerspoon 2 process integration has not been exercised.

## WMBridge investigation, 2026-10-23

A second route was investigated after the initial C-API proof:
Apple's private Objective-C `SLSBridged…Operation` classes, as reported in
[KiwiDesk issue 884](https://github.com/KiwiCanopy/KiwiDesk/issues/884) and
[its permission investigation](https://github.com/KiwiCanopy/KiwiDesk/issues/889).
This harness implements the reported signatures independently; it does not
include KiwiDesk source. Research reference: KiwiDesk commit
`ced9f0aeb21359e71b064b5a98d983ae5b55fc8c`.

| Test | Observed result on macOS 27.0.1 build 26A434 |
| --- | --- |
| Operation discovery | Managed-display query, window-membership query and window-move classes all resolved. Other write operations were not invoked. |
| Read-only bridge query | All seven Spaces, their order/types and active desktop matched the C API. Membership matched for 16 sampled window IDs. |
| Permission isolation | CLI launch reported Accessibility trust true. LaunchServices launch of a separate temporary app identity reported false, while the same read checks passed. No permission request API or TCC change was used. |
| Bridge-owned window | One move from desktop 6 to adjacent desktop 7 succeeded with Accessibility trust false; two C-API membership readbacks matched. Disposable window closed. About 0.86 seconds including setup/cleanup. |
| Foreign-process window | A second disposable AppKit application owned the target window. With controller Accessibility trust false, one bridge move sent it from desktop 6 to desktop 7. Two consecutive checks agreed through both bridge and C membership readers, and WindowServer changed its onscreen flag from true to false. About 1.31 seconds including setup/cleanup. |
| Cleanup | The target app exited and the window disappeared from WindowServer. The current desktop remained 6. Production Hammerspoon files were unchanged and no reload was performed. |

**Result:** this private bridge can transfer a window belonging to another
process on this machine without an Accessibility grant. In this phase the foreign process
was our isolated disposable test app. The later Rex pilot below adds an actual
application round trip; Safari/Codex, following a moved window, visual behaviour
on the destination desktop, multi-monitor operation and future OS builds remain
untested. This
does not establish that all of Window Factory can run without Accessibility:
its normal cross-app capture/geometry work uses the public Accessibility API.

The bridge is initialized with real AppKit loading. Read operations return
objects; the move operation returns void, so dispatch alone never counts as
success. Objective-C exceptions and unsupported signatures fail the probe.
No native desktop creation/deletion, switching, metadata writes, input synthesis
or pre-existing user-window movement was needed. A foreign target can only be the new
child app's self-reported window after matching its WindowServer owner PID;
there is no CLI argument for an arbitrary window ID. The child closes on a
private stdin quit command, stdin EOF, or a 12-second safety timeout.

The helper shares its existing C query implementation in `space-runtime.h`.
The legacy `probe-move` command's behaviour is retained. Builds now also produce
`.build/BridgeProbe.app` and `.build/WindowProbe.app`; neither is installed or
registered for login. The live-check task launches only the read-only bridge
query through LaunchServices and reports its effective trust state. The normal
test task checks argument rejection and protects existing report files and
symlink targets. It never dispatches a valid move command.

For a deliberate desktop pilot, take fresh IDs from a snapshot, then invoke
`bridge-probe-own SOURCE TARGET` or `bridge-probe-foreign SOURCE TARGET` through
`open -n -g -W native/space-helper/.build/BridgeProbe.app --args … --report PATH`.
Use an absolute, new temporary report path: existing files are rejected, never
overwritten. `open` finishing is not probe success: inspect the report's
`ok`, verification and cleanup fields. Keep the source desktop selected;
these probes do not follow the window or touch existing windows. Invalid CLI
arguments are rejected before opening AppKit or creating a report.

## Rex application pilot, 2026-10-23

Tested Rex Beta 0.1.0 build 1381 on macOS 27.0.1 build 26A434.
One File > New Window action created an empty fish session/window on desktop 6.
A before/after inventory identified exactly one additional normal Rex window;
the eight existing Rex windows and their memberships formed the baseline.

The bridge moved only that new window from desktop 6 to adjacent desktop 7,
then returned it to desktop 6 for UI cleanup. Both hops passed two consecutive
checks through the bridge and C membership readers, together with matching
WindowServer onscreen flags (false away, true back). The complete round trip
took about 1.01 seconds, including a half-second pause at the destination.
The helper reported Accessibility trust false. The active desktop and all eight
original Rex windows' memberships stayed unchanged during the bridge operation.
No geometry request, simulated drag or Space-switch command was used.

**Cleanup incident and recovery:** closing the disposable window retained its
empty Rex session. Selecting that session in an original window and using the
File menu's Close Session also closed the containing original window view.
The retained working terminal session survived. A replacement view was opened,
its original session selected, and the replacement was returned to the original
desktop through the bridge. The two empty sessions were removed; removing the
second through its own sidebar context menu while the working session remained
selected preserved the recovered view. Final inventory: same Rex process,
eight windows, seven original IDs/memberships unchanged plus one replacement
view on its original desktop, with the disposable window gone. The original
view's exact geometry was not recorded and is not claimed restored. Desktop
context changed during UI recovery; the bridge round trip itself did not change
it, and the final query again reported the initial desktop. Do not describe the
whole pilot as leaving every original window identity untouched.

For future pilots, close a retained empty session through its own sidebar
context menu while an existing working session stays selected. Do not select
the test session in an existing view and invoke the File menu's Close Session.
The recovery did not require a Rex restart. Hammerspoon configuration and runtime
were not changed or reloaded.

The isolated harness adds:

- `rex-inventory`: read-only Rex PID, version, normal window IDs/memberships and
  active Space; no titles or terminal contents.
- `bridge-probe-rex SOURCE TARGET RECEIPT`: one adjacent desktop round trip,
  without following, targeting only the one new window identified by a temporary
  creation receipt. It validates the exact bundle/PID, baseline inventory and
  source membership before dispatch. Existing windows cannot be named directly.
- `bridge-restore-rex TARGET RECEIPT`: recovery of a similarly receipt-identified
  new replacement view, with a valid ordinary target and unchanged inventory.
  It verifies membership through both readers and the target's window list;
  it does not activate an app or switch the current desktop.

A receipt is temporary JSON with `pid`, `windowID` (decimal string), and
`beforeWindows` (the before-creation inventory's `windows` dictionary).
It must come from an immediately observed creation; do not forge one for an
existing window. Receipts and runtime reports are not committed. The normal
validation tasks do not run either Rex move command. The helper does not create
or close Rex windows; those explicit UI steps remain separate from transfer.

This establishes the private bridge's Rex round-trip capability for one build
and an empty session. It does not fix Rex startup geometry or establish
move-and-follow, automated creation/cleanup, live-workload, multi-monitor,
Safari/Codex or Hammerspoon 2 integration compatibility.

## Build and read-only checks

From the repository root (fish-compatible):

```fish
mise run native-spaces-build
mise run native-spaces-test
native/space-helper/.build/space-helper snapshot
native/space-helper/.build/space-helper window-spaces 123
mise run native-spaces-check-live
```

Replace `123` with a known window ID. Nonexistent IDs produce an empty membership
list. IDs are decimal strings in JSON, preserving 64-bit Space IDs across a
JavaScript boundary. The output contains IDs/types only, with no window titles,
contents, URLs, screenshots, or saved workspace recipes.

The project selects Objective-C for this small C/Objective-C platform bridge.
`build.sh` uses the already installed Xcode SDK through `xcrun`, with ARC and
warnings as errors, then ad-hoc signs the local binary. No packages or runtimes
are downloaded. Generated output stays in this component's ignored `.build/`.
Tests of CLI rejection/help do not connect to WindowServer. Live queries need
the logged-in GUI session: the Codex execution sandbox returned
`display-spaces-unavailable`; approved execution outside that sandbox worked.
This is distinct from granting Accessibility or Screen Recording permission;
neither was requested or changed for this proof.

For an optional read-only Hammerspoon comparison, run this in its Console:

```lua
assert(loadfile("/absolute/path/to/native/space-helper/hammerspoon-reference.lua"))("/private/tmp/native-space-reference.json")
```

Then, from the repository root:

```fish
mise exec -- node native/space-helper/compare-reference.cjs native/space-helper/.build/space-helper /private/tmp/native-space-reference.json
```

Run the comparison promptly while the same desktop/windows remain present.
The reference file is temporary runtime evidence, never repository input.

## Explicit disposable-window move

`probe-move SOURCE_SPACE_ID TARGET_SPACE_ID` is deliberately separate from the
read-only checks. It accepts Space IDs, **never an existing window ID**. Before
creating a window it requires the source to be current and the destination to
be an adjacent ordinary user Space on the same display. It creates its own
small labelled window without activating the app, verifies ownership by PID
and source membership, sends one move request, and checks membership twice.
It closes its window on success or failure. It never switches desktops,
synthesizes input, moves another app's windows, or changes Space topology.

The direct API returns no success status. Only verified membership counts as
success; a no-op, Space change or timeout is a failure. There is no automatic
retry through a more invasive method. Run this only as a deliberate desktop
pilot with current IDs from a fresh snapshot; desktop ordinal numbers are not
Space IDs. Multiple-display, full-screen and sticky-window moves remain outside the
accepted proof. The later bridge proof covers a separate disposable test app.

## Sources and compatibility

Private declarations and query masks follow the MIT-licensed
[Hammerspoon 1.1.1 spaces implementation](https://github.com/Hammerspoon/hammerspoon/tree/1.1.1/extensions/spaces).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
The separately researched [SpacesManager findings](https://github.com/michaeltorbert/spaces-manager#tahoe-private-api-findings)
describe the ownership distinction on macOS 26.5; our local probe establishes
only the narrower result above on macOS 27.0.1. Symbols are dynamically checked,
but presence is not a promise of behaviour across macOS updates. Re-run the
read-only checks first after an OS update. Do not make product controls depend
on an unverified dispatch result.
