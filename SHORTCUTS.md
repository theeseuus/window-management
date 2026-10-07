# Complete Keyboard Shortcut Reference

2026-10-07.1

Hyper = `Control + Option + Command`

## App Launching (Hyper + key)

These commands are owned by Raycast, not Hammerspoon.

| Category | Shortcut | Action |
| --- | --- | --- |
| Terminals | `Hyper + T` | Ghostty |
| Terminals | `Hyper + Shift + T` | iTerm |
| Browsers | `Hyper + B` | Safari |
| Browsers | `Hyper + Shift + B` | Chrome |
| Editors | `Hyper + E` | BBEdit |
| Editors | `Hyper + Shift + E` | VS Code |
| Passwords | `Hyper + 1` | 1Password |
| Passwords | `Hyper + Shift + P` | Apple Passwords |
| Messengers | `Hyper + G` | WeChat |
| Messengers | `Hyper + Shift + G` | WhatsApp |
| Network | `Hyper + Shift + L` | Little Snitch |
| People | `Hyper + C` | Contacts |
| People | `Hyper + Shift + C` | Calendar |
| Notes | `Hyper + N` | Apple Notes |
| Notes | `Hyper + Shift + N` | Obsidian |
| Media | `Hyper + M` | Mail |
| Utilities | `Hyper + F` | Finder |
| Utilities | `Hyper + ,` | System Settings |
| Utilities | `Hyper + K` | Shortcut Viewer |
| System | `Command + Space` | Raycast |
| System | `Option + Space` | Spotlight |

## AI Apps (F-keys)

| Shortcut | Action |
| --- | --- |
| `F13` | Claude |
| `F14` | Codex |
| `F15` | ChatGPT |
| `F16` | Emoji Viewer |

## Native macOS Space traversal

| Shortcut | Action |
| --- | --- |
| `Control + Left` | Move me to the previous Space |
| `Control + Right` | Move me to the next Space |

These are native macOS bindings. Hammerspoon does not replace them.

## Window Management (Hammerspoon)

| Shortcut | Action |
| --- | --- |
| `Hyper + W` | Cross-app window switcher, forward |
| `Hyper + Shift + W` | Cross-app window switcher, backward |
| `Hyper + H` | Focus the closest vertically overlapping window to the left |
| `Hyper + J` | Focus the closest horizontally overlapping window below |
| `Hyper + K` | Focus the closest horizontally overlapping window above |
| `Hyper + L` | Focus the closest vertically overlapping window to the right |
| `Hyper + Left` | Move the focused window to the previous Space and follow it |
| `Hyper + Right` | Move the focused window to the next user Space and follow it |
| `Hyper + Up` | Save frame, then centred half-width/full-height |
| `Hyper + Down` | Restore the previously saved frame |
| `Hyper + [` | Narrow the focused window around its centre |
| `Hyper + ]` | Widen the focused window around its centre |
| `Hyper + -` | Cycle canonical size: `1/2` → `1/4` → `1/8` → `1/16` → `1/2` |
| `Hyper + Shift + -` | Reverse the canonical size cycle |
| `Hyper + =` | Advance through canonical positions for the current canonical size |
| `Hyper + Shift + =` | Move to the preceding canonical position for the current size |
| `Hyper + 2` | Cycle halves: left → right |
| `Hyper + 3` | Cycle thirds: left → centre → right |
| `Hyper + 4` | Cycle quarters: top-left → clockwise → bottom-left |
| `Hyper + 8` | Cycle eighths clockwise around a 4×2 grid |
| `Hyper + Shift + 2/3/4/8` | Run the geometry cycle in reverse |
| `Hyper + Return` | Centre horizontally; preserve width, height, and vertical position |
| `Hyper + Shift + Return` | Maximize |
| `Hyper + D` | Minimize |
| `Hyper + S` | Toggle stash offscreen/restore |
| `Hyper + Shift + S` | Accordion the active app's windows from the focused window |

`Hyper + -` and `Hyper + =` are stateless canonical-geometry controls; their
Shift variants run the same cycles in reverse. The older `Hyper + 2/3/4/8`
cycles remain available for comparison.

The example Raycast map above also assigns `Hyper + K` to Shortcut Viewer,
while TheseusWindow reserves it for upward spatial focus. If both bindings are
configured, remove or reassign the Raycast binding so that each shortcut has a
single owner.

The enabled menu-bar Space indicator has no shortcut. It renders the current
user-Space ordinal as `[n]`, `[?]` when unavailable, and `[—]` for a full-screen
or tiled Space.

## Workspace Management (Hammerspoon)

These commands are supplied by the independent TheseusWorkspace Spoon in the
reference `Hammerspoon/init.lua` configuration.

| Shortcut | Action |
| --- | --- |
| `Hyper + R` | Open or bring forward the unified Workspaces window |
| `Up / Down`, in the layout library | Select the previous / next visible layout |
| `Return`, from search or the layout list | Restore matching existing windows here |
| `Command + Return`, in the layout library | Establish here: reuse local windows and create supported missing slots |
| `Command + Delete`, in the layout library | Confirm deletion of the selected saved layout |
| `Return`, in the ready capture name field | Save the captured layout after naming it |
| `Escape`, in capture or confirmation | Cancel and return to the preceding view without saving or deleting |
| `Escape`, in the layout library | Close Workspaces |

**Capture…** opens the capture view in the same window. The former
`Hyper + Shift + R` binding is no longer in the reference map. Search by layout
name or app, click a row to select it, or double-click to Restore. The bottom
bar has Restore and Establish buttons; a row's actions button or right-click
offers the same operations and Delete. Previews are generated from each saved
recipe's actual window geometry, including newly captured recipes.
Focused buttons keep their normal keyboard activation; Return on a focused
button performs its labelled action.

Alternatively, right-click a layout in the library and choose **Delete saved
layout…**. The confirmation names the exact layout and defaults to Cancel.
Delete removes only the saved recipe, without moving or closing windows, apps,
or Spaces. The library refreshes and keeps its search; deleting the final layout
leaves the empty library open with Capture available. Deletion has no undo.
The confirmation is inline in the same window. This adds no global shortcut.

To establish a saved layout in the current Space, highlight it and press
`Command + Return`, click **Establish here**, or right-click and choose
**Establish here**. Independent new-window support is Ghostty (1.3+ with AppleScript
enabled), Finder, Safari, BBEdit, Chrome, and ChatGPT/OpenAI desktop with an
enabled **File → New Window** menu. Claude can supply its launch-created main
window when closed or reuse a local window; additional missing Claude windows
are reported because no safe independent-window command is available.
Establish launches supported apps if needed, reuses local
windows, creates only missing slots, and verifies placement. It never borrows
another Space's windows. Unsupported missing slots are reported. First use may
request macOS Automation access; a timed-out command is not retried automatically.
Cold launches allow up to about 15 seconds and count startup windows before
requesting extras. ChatGPT uses Accessibility rather than AppleScript Automation;
New Chat is never substituted for New Window. Repeat after a successful Establish
to reapply geometry without duplicates.
Keep this Space selected until completion. This is a panel-local gesture,
not another global Hyper binding; ordinary Return still performs Restore only.

Restore waits for verified frame placement before showing its completion
notice. Missing or failed applications are named; shortcuts are unchanged.

The capture view opens with naming and Save disabled. Keep windows still until
the captured count appears and the name field is enabled. Moving windows after
that point does not change what Save records. Cancel/Escape discards the unsaved
snapshot and returns to the library; closing the window also discards it.
Repeating `Hyper + R` brings the same window forward without recapturing.

Capture requires confirmation before replacing an existing name. Restore uses
application identity and normalized geometry, reports missing recipe slots, and
leaves extra windows untouched. Restore does not launch apps or create windows;
those actions belong only to the explicit Establish operation. Neither operation
moves the whole group between Spaces or restores window contents.
