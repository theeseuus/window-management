# Native Window Factory: build and transition

Updated 2026-10-23. The native build is underway on `native-window-factory`.
The working Hammerspoon baseline stays in service while the separate candidate
earns acceptance. Build and pilot instructions are in the
[native candidate README](../native/window-factory/README.md); earlier Space
feasibility evidence is in the [native proof record](../native/space-helper/README.md).

## Product scope and architecture

Build a focused native macOS app for capturing the eligible windows on the
current ordinary desktop, saving normalized layouts, restoring existing
windows, and establishing supported missing windows without duplicates.
Preserve the separation between Restore and Establish here. Recreating browser
URLs, terminal commands, selected chats or other application contents is later
work. Coordinated animation is also outside the first replacement.

Use Swift with AppKit for the application/window lifecycle, keyboard-first
library and controls. Keep the small Objective-C private-API bridge behind a
typed interface; both belong to the native application initially. A separate
installed helper is optional future isolation, not a prerequisite. No embedded
browser, Hammerspoon 2 dependency or runtime Lua conversion is required.

Separate responsibilities inside that application:

- Layout catalog and matching: versioned data, normalized geometry, deterministic
  current-desktop eligibility and one-to-one window/slot assignments.
- Operation coordinator: capture snapshots, cancellation, single-operation
  guards, progress, bounded retries, membership/frame verification and receipts.
- Application adapters: exact bundle IDs and reviewed New Window operations;
  unsupported independent-window creation remains an explicit limitation.
- macOS services: Accessibility geometry/focus, app lifecycle, native Space
  queries/movement, hotkeys and event-driven refresh.
- Native panel: search, arrows, Return, Command-Return, Escape, Capture/Cancel,
  previews and useful per-app failure reports.

Use public Accessibility for cross-app window geometry/focus. Treat private
Space capabilities as optional at runtime, verified against real reads. A
failed or absent private path must not cause a fake success or a speculative
move. After an owned transition, re-query Space state and publish an internal
state-change event directly. External NSWorkspace notifications are additional
triggers: the follow probe observed none, which is not evidence that a complete
AppKit app will never receive them. Avoid continuous whole-desktop polling.

Import the existing schema-v1 layout catalog by copying and validating it,
leaving the original recoverable for Hammerspoon. Native application data owns
the imported layouts; chezmoi owns durable machine configuration. There must be
no two writers reconciling the same catalog. The exact production paths and
catalog handoff are implementation decisions, not changes made by this plan.

## Corrected scope and effort

This is a port of an existing working product. Reuse its feature contract,
schema, geometry matching, adapter operations and acceptance examples. All 16
entries in `app_adapters.lua` belong to the initial build: Rex, Ghostty, Finder,
Safari, BBEdit, Chrome, ChatGPT, Codex, Claude, Excel, Word, PowerPoint, Keynote,
Pages, Numbers and Mail. Preserve their existing limitations, including Claude's
launch-only support. Rex/Safari/Codex are the first smoke test, not a reduced
product scope or a prerequisite for adding the other known adapters.

Allow approximately **5–11 hours of focused effort for the initial core port**:
roughly 1–2 hours for the native shell/catalog, 2–4 for capture/matching/Restore
and Establish using the full registry, and 2–5 for integration checks and the
first desktop pilots. Aim for a first working candidate in one focused session,
then address observed problems in a follow-up session. This is a planning range,
not a guarantee of app compatibility or permission acceptance in that time.
The prior 40–70-hour, three-app estimate treated too much existing work as new
and has been superseded.

The first source build includes the native library, capture/save/cancel,
search/preview, Restore/Establish, import/export/delete/report, schema-v1
compatibility and all 16 adapter definitions. Compile and pure-core checks do
not establish live app compatibility. Validate the existing supported operations
on the installed versions, recording failures rather than claiming all entries
work merely because they decode. Native catalogue migration and Hyper+R handoff
remain explicit adoption steps after the pilot.

The broader TheseusWindow geometry cycles, directional focus, switcher,
stash/restore, Space badge and move-and-follow remain in Hammerspoon. App-state
recreation, coordinated animation, general distribution, updater/installer and
multi-monitor release acceptance are later work. Estimate those separately if
and when they are selected; they do not block starting the core port.

## Keybindings and ownership

Keep the present division of labour:

| Binding or function | Initial owner | Native transition |
| --- | --- | --- |
| Hold Tab to produce Hyper (Control+Option+Command) | Karabiner | Keep this mapping. The native app receives the resulting chord. |
| App launching, including Hyper+T for Rex | Raycast | Keep existing launcher ownership. |
| Hyper+R opens Window Factory | Hammerspoon | Pilot the native panel from its menu first, or an audited temporary chord. Transfer Hyper+R only after native acceptance; disable the old handler before enabling the new one. |
| Arrows, Return, Command-Return and Escape inside the panel | Hammerspoon panel | Native AppKit actions and first-responder handling. Preserve existing semantics. |
| Other window-management chords | TheseusWindow | Remain in Hammerspoon until each native feature is deliberately adopted. |
| Control+Left/Right desktop navigation | macOS | Keep the system shortcuts. |

Use the macOS registered-hotkey API (`RegisterEventHotKey`) for configured
global chords. Prefer exclusive registration, inspect return statuses, and
report conflicts rather than silently sharing a chord. Registration is not a
complete conflict audit across event taps or remappers: the handoff must ensure
one actual owner. No global keystroke logger or Input Monitoring is needed just
to receive these registered chords. The installed Xcode SDK still exposes this
API; validate Hyper and keyboard-layout handling before shortcut handoff. The
current candidate registers no global shortcut.

Keep the binding table in an inspectable configuration file managed through
chezmoi on this Mac, with defaults, validation and explicit reload. A settings
view can display effective bindings and conflicts; it must not silently become
a second writer to a chezmoi-managed file. Audit the existing Hyper+K overlap
documented in SHORTCUTS.md during migration; do not change it as part of this
proposal. In-app keys use local native event handling, not global registration.

Rollback releases the native hotkeys and restores the old binding owner. Do not
register both implementations for Hyper+R or move-and-follow simultaneously.

## Permissions, packaging and adoption

The final native bundle needs owner-granted Accessibility for capture, placement
and focus. Per-app Automation grants apply only to adapters using Apple Events;
request them when those specific integrations are used. The private transfer
alone passed without AX trust, but the follow probe used existing launcher AX
trust to verify and set exact keyboard focus. No new grants were made in the
proof. Screen Recording is not required for outline previews or the core plan.

Use a stable app/bundle identity and a repeatable local Xcode build. Stable
signing and permission behaviour need validation; the ad-hoc proof is not a
shipping identity. Offer launch at login deliberately, not as a development
side effect. Keep diagnostics bounded and avoid terminal contents, browser URLs
and window titles in routine operation reports.

Adopt the native panel first while TheseusWindow remains available. Require
keyboard acceptance through the real launcher, repeated three-app Establish
with no duplicates, current-Space isolation, honest failure/cancellation, and
clean restart before the Hyper+R handoff. Validate the full carried-over adapter
list; port broader window controls in separate accepted changes. The tagged Hammerspoon version remains
the fallback until the replacement has had ordinary daily use.


## Complete controller port selected, 2026-10-24

The owner selected the complete TheseusWindow controller for native Window
Factory, in this order: (1) size/position cycles, centring, frame restore,
width changes and maximize/minimize; (2) directional focus; (3) stash/restore;
(4) the window switcher; (5) native Space move-and-follow and its indicator.
Existing physical shortcuts remain the contract. Each group needs a harmless
live pilot before acceptance; retain the Hammerspoon implementation and a
reversible binding handoff until then. Configurable command bindings and the
main-window/settings redesign follow the controller port, not this first group.

The geometry pilot adds nineteen native Carbon hotkeys, disabled by default,
and a settings switch for activating/releasing that group. The managed loader
can release only the Hammerspoon geometry group via `geometryHotkeys = false`;
the Spoon defaults to true for standalone/fallback use. Do not register both
implementations. Registration is exclusive and all-or-nothing on a reported
conflict, but explicit loader ownership remains necessary. No input monitor or
Space mutation is needed for geometry. The app may start with `--background`
to register accepted controls without presenting its library.
