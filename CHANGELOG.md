# Changelog

All notable changes to Xius Marks Bar are documented in this file.

## 1.4.1

### Fixed
- Double-clicking the target frame or portrait out of combat opens the radial target-mark wheel again.
- Uses `OnDoubleClick` plus a 0.35s `OnMouseDown` / `PostClick` fallback for `SecureUnitButtonTemplate`.
- The wheel still centers on the cursor, and it closes immediately when combat starts.

## 1.4

### Added
- Settings page uses three sub-tabs in Xius Core: General, Marks & Wheels, and Timers & Checks.
- Each target mark (1–8), each world marker (1–8), and both Clear buttons can be shown or hidden on their own.
- Xius Core mover registration for the Marks Bar unlock flow.
- Profile sync keeps `XMB.db`, `XiusMarksBarDB`, and `XiusUIDB.marks` on the same table when Xius Core switches profiles.
- Queued visibility updates so group and leader rules refresh without extra work every frame.

### Changed
- TOC title uses the gold Xius Marks Bar styling. Main TOC also lists Forever (`16001`) and loads for standard, forever, and camelot.
- `LoadSavedVariablesFirst` is set so account settings are ready before the bar builds.
- Removed leftover XiusUI / XiusUISettingsLib checks. Xius Core is the only settings host.
- Role check uses a secure `/rolepoll` button so it does not hit protected `InitiateRolePoll` blocks.
- Flag and star open options from `PostClick` instead of `OnMouseUp`, which keeps combat toggles clean.
- Mark rows pack only the buttons that are turned on, so the strip stays tight when marks are hidden.
- Secret-value helpers treat a failed `issecretvalue` / `canaccessvalue` call as secret, so Forever never does math on restricted values.

### Fixed
- Layout and position restore wait out combat lockdown instead of fighting secure frames.
- Target-mark highlights skip redraw when the active mark has not changed.
- Mark wheel no longer hooks Blizzard unit frames or `SecureActionButton_OnClick` (those paths tainted party, raid, and mark clicks). Wheel spokes close with an insecure `PostClick` / deferred timer instead.
- Compact unit frame `HookScript` path removed; unit clicks use the secure unit-button hooks only.
- Visibility for group or leader no longer drops the bar when leader/assistant status is unknown.

## 1.3.8

### Added
- Xius Core is required. `/xmb` opens the Marks page in that window.
- Show the bar, and visibility for always, group or instance, or leader or assistant.
- Account settings stay on the same table Xius Core uses for profiles.

### Changed
- The bar wraps the buttons that are turned on. A mark row widens it only while that row is open.
- Key bindings are declared once, in this addon's `Bindings.xml`.

### Fixed
- Starting a new pull cancels the countdown already running, including the Blizzard raid countdown.
- The mark wheel still builds if the client has no portrait mask texture.

## 1.3.7

### Added
- Mark wheel modifier. In `/xmb`, under Mark Wheel, choose Double-click, Shift + double-click, Alt + double-click, or Ctrl + double-click. The chosen key must be held alone. A plain double-click stays the default.

## 1.3.6

### Added
- Radial mark wheel. Double-click a unit, nameplate, or unit frame to mark a target. Double-click the ground to place world markers. Double-click is outside combat. The same wheels open from key bindings during combat.
- Key bindings for every target mark, world marker, both clear buttons, and both wheels. Set them on the addon options page or under Options, Keybindings, AddOns. Every bind starts blank.
- Retail support alongside Forever. The addon loads on modern World of Warcraft (interface 120000–120107), World of Warcraft Forever (16000–16001), and Camelot.
- The star and the flag can each be hidden. The 5, 10, and 20 second countdowns can each be turned off on their own.
- Addon-list icon.

### Changed
- Target marks use secure raid-target buttons, so placing and clearing a mark works in combat on retail and Forever.
- Click the running countdown again, or right-click it, to cancel. The pull uses the group countdown when you are allowed to start one, and a chat countdown otherwise. Leaders announce on raid warning.
- The options page scrolls, and key binds are set by clicking a box and pressing a key or mouse button.
- World markers report in chat when you are not in a group, or when a raid requires leader or assistant.

### Fixed
- The bar stays where you placed it across UI scale changes and when it grows up or down.
- Option checkboxes draw their own check when the client skin does not.
- Secret unit values inside instances no longer break the bar or the mark wheel.
- If you log in or reload in combat, the bar and the wheel appear when combat ends.

## 1.0.1

### Fixed
- Target marks again use secure `/tm` macros so marking works without protected-function blocks on Forever.
- Removed target-mark highlight updates that read `GetRaidTargetIndex` (secret values on this client caused taint compare errors after every mark).
- World marker buttons no longer use `pressAndHoldAction`, which could fire place/clear twice on one click.
- Target mark macros only apply when you have a living target (no empty-unit fallback).

### Improved
- Shared hover handlers and coalesced layout requests after zoning / UI scale changes to cut avoidable CPU work.
- Stale pull-timer tickers cancel immediately when a new countdown starts.
- Ready-check secure button registers for both mouse-up and mouse-down so it follows client click timing.

## 1.0.0

### Added
- Initial release for World of Warcraft Forever (TOC `16001`).
- Flag / star click-to-expand world and target mark rows.
- Pull timers (5 / 10 / 20), ready check, and role check on the compact bar.
- Movable, scalable bar with options panel and `/xmb` slash commands.
