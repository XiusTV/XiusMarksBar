# Changelog

All notable changes to Xius Marks Bar are documented in this file.

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
