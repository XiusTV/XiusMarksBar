# Changelog

All notable changes to Xius Marks Bar are documented in this file.

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
