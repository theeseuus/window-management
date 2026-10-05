# Complete Keyboard Shortcut Reference

2026-10-05.2

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
