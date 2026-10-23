# Native Window Factory: proposed build and transition

Planning estimate, 2026-10-23. This is a proposal, not authorization to deploy
or a delivery commitment. The working Hammerspoon baseline stays in service
while native pieces earn acceptance. Live feasibility evidence is in the
[native proof record](../native/space-helper/README.md).

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

## Effort estimate

These are engineering-effort ranges for one focused implementation stream with
agent assistance and owner desktop acceptance. Existing Lua behaviour/tests
and native probes reduce discovery work, but do not eliminate porting and live
application compatibility work. Hours are not unattended model runtime or a
promise that desktop acceptance will happen in one session.

| Milestone | Incremental effort | Acceptance |
| --- | --- | --- |
| Native shell, catalog, capture/restore | 12-20 hours | Reliable keyboard input/lifecycle, validated catalog import, current-desktop isolation and frame verification. A rough demonstrator may appear after 8-16 hours within this phase. |
| Establish for Rex, Safari and Codex | 12-20 hours | Fresh creation, reuse, no duplicates, normal Safari startup, cancellation and honest failure reports across repeated pilots. |
| Personal-use hardening and cutover | 16-30 hours | Permissions, identity/signing, keybinding handoff, startup/relaunch behaviour, migration/recovery and regression/use checks. |
| **First daily-use target for those three apps** | **40-70 hours total** | Roughly 5-9 focused working days; allow around 2-3 calendar weeks for interrupted work and owner acceptance. |

Additional scope, not hidden inside that total:

- Remaining current adapter coverage: approximately 12-24 hours, depending on
  available app versions and permission/creation behaviour. The current registry
  has 16 entries, including a launch-only limitation; entry count is not proof
  of universal creation support.
- Replacing the broader TheseusWindow controls (geometry cycles, directional
  focus, switcher, stash/restore, Space badge, move-and-follow): another 20-40
  hours. They can remain in Hammerspoon during the Window Factory cutover.
- General distribution with multi-monitor acceptance, installer/update support,
  broader compatibility and release polish: another 40-80 hours. Signing identity
  and any release accounts remain owner-controlled.

Re-estimate after the first native capture/restore acceptance and the first
three-app Establish pilot. The largest uncertainty is app/OS behaviour, focus
and recovery, not drawing the panel. The estimate excludes reconstructing app
contents and any rewrite of the OS or disabling SIP.

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
API; validate Hyper and keyboard-layout handling in the first native milestone.

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
clean restart before the Hyper+R handoff. Add the remaining adapters and window
controls in separate accepted changes. The tagged Hammerspoon version remains
the fallback until the replacement has had ordinary daily use.
