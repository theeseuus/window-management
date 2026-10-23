# Standalone native Space helper proof

This isolated Objective-C executable tests whether a native companion can retain
Space information without depending on Lua or installing Hammerspoon 2. It is
not integrated into either production Spoon and is not installed or started at
login. There is no background polling or persistent helper process.

## Observed on this Mac, 2026-10-23

Environment: Apple Silicon, macOS 27.0.1 build 26A434, Hammerspoon 1.1.1,
Xcode macOS SDK 27.0, Apple clang 21.0.0 (clang-2100.3.34.2).

| Proof | Observed result |
| --- | --- |
| Native read-only query | One display, seven ordinary Spaces; ordered topology, types and current Space matched Hammerspoon. |
| Window membership comparison | Exact membership matched for five standard windows. All 104 window-ID entries in Hammerspoon's per-Space lists appeared in the raw native lists. Hammerspoon filters some canvas IDs from its own output. |
| Modern compatibility-workspace protocol | Preliminary `SLSSpaceSetCompatID` call returned unexpected status 1834979; no window move request was sent. The disposable window closed. This exploratory implementation is not retained. |
| Direct `SLSMoveWindowsToManagedSpace` | One request moved the helper-owned disposable window from user Space 6 to adjacent user Space 7. Two consecutive readbacks reported only the destination. Completed in about 0.87 seconds including window creation and cleanup. |
| Cleanup and isolation | Active Space remained 6. A separate post-exit query returned no membership for the closed test window. Production Hammerspoon files were not changed or reloaded. |

**Conclusion:** native queries and moving a caller-owned window work here.
Moving another application's window remains unproven. These results do not
establish that a native helper can replace the existing drag-and-key transport
in TheseusWindow, nor that the private move API fixes Rex startup placement.
Actual Hammerspoon 2 process integration has not been exercised.

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
Space IDs. Multiple-display, full-screen, sticky-window and foreign-app moves
are outside the accepted proof.

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
