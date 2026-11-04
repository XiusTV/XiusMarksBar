# Xius Marks Bar

A compact raid marking bar for **modern World of Warcraft** and **World of Warcraft Forever**. Click the **flag** for world markers, click the **star** for target markers, or double-click a unit or the ground to open a mark wheel. Pull timers, ready check, and role check stay on the bar. Near-black slots, thin muted gold borders, and a see-through dark background sit quietly alongside the default action bars.

## Features

### Click-to-Expand Marking

- **Flag → World Marks:** All 8 world markers plus Clear All. Left-click places or removes a marker. Right-click removes it.
- **Star → Target Marks:** All 8 raid target icons plus Clear Mark. Left-click marks your target. Click the same mark again, or right-click, to clear it.
- **One Row at a Time:** Opening one row closes the other. Click the open icon again to collapse.
- **Works in Combat:** Opening, closing, and marking all work mid-fight.
- **Show Only What You Use:** The star, the flag, and each countdown can be hidden from the options page.

### Mark Wheel

- **Double-click a unit** (mob, player, nameplate, or unit frame) to open a target-mark wheel on your cursor.
- **Double-click the ground** to open a world-marker wheel.
- **In combat,** bind the wheels. Double-click is outside combat only.
- **Right-click or Escape** closes the wheel. Choosing a mark closes it too.

### Group Tools

- **Pull Timers (5 / 10 / 20):** Starts the group countdown when you are allowed to, otherwise a chat countdown that ends in "GO!". Click the same button again, or right-click, to cancel.
- **RC (Ready Check):** Starts a ready check. Leader or assistant only.
- **R (Role Check):** Asks everyone to choose a role.

### Bar

- **Blends In:** Near-black slots with thin muted gold borders. Borders warm up on hover or while a row is open.
- **Small Footprint:** A slim line of buttons until you open a row.
- **Smart Growth:** Grows toward the middle of the screen, or always up, or always down.
- **Out-of-the-Way Tooltips:** Tooltips sit above or below the whole bar.
- **Pixel-Snapped:** The bar stays where you placed it when you resize it or the UI scale changes.
- **Key Bindings:** Every mark, both clears, and both wheels can be bound. Nothing is bound until you choose a key.

## Display States

- **Collapsed:** Flag • Star • 5 • 10 • 20 • RC • R • Move grip
- **World Marks Open:** Blue Square • Green Triangle • Purple Diamond • Red Cross • Yellow Star • Orange Circle • Silver Moon • White Skull • Clear All
- **Target Marks Open:** Star • Circle • Diamond • Triangle • Moon • Square • Cross • Skull • Clear Mark

## Controls & Slash Commands

| Command / Input | Action |
| --- | --- |
| `/xmb` | Open the options page |
| `/xmb config` or `/xmb options` | Open the options page |
| `/xmb lock` / `/xmb unlock` | Lock or unlock bar movement |
| `/xmb reset` | Move the bar back above the action bar |
| `/xmb collapse` or `/xmb hide` | Close the open mark row |
| `/xmb scale 60-160` | Set the bar size |
| `/xmb help` | List the commands |
| Left-Click Flag / Star | Open or close world / target marks |
| Right-Click Flag, Star, or Grip | Open options |
| Drag the Grip | Move the bar when it is unlocked |
| Left-Click a countdown | Start that pull. Click again to cancel |
| Right-Click a countdown | Cancel the pull |

## Configuration

Open settings with `/xmb`, or **Game Menu → Options → AddOns → Xius Marks Bar**:

- **Bar:** Lock position, only show in a group or instance, show or hide tooltips.
- **Marks On The Bar:** Show or hide the star and the flag.
- **Countdown:** Show or hide 5, 10, and 20 separately.
- **Group Checks:** Ready check and role check.
- **Mark Wheel:** Double-click units, and double-click the ground.
- **Expand Direction:** Auto, always up, or always down.
- **Bar Scale:** 60% – 160%.
- **Key Bindings:** Click a box, then press a key or mouse button. Right-click a box to clear it. Clear All Keybinds wipes every bind for this addon.
- **Reset Position / Collapse Marks:** Put the bar back, or close the open row.

Settings are saved per account in `XiusMarksBarDB`.

## Installation

1. Download **XiusMarksBar-1.3.6.zip** from the latest [release](https://github.com/XiusTV/XiusMarksBar/releases).
2. Extract the `XiusMarksBar` folder into:
   - Retail: `World of Warcraft\_retail_\Interface\AddOns`
   - Forever: `World of Warcraft Forever\Interface\AddOns`
3. The folder should contain `XiusMarksBar.toc`, `Config.lua`, `Core.lua`, `Flywheel.lua`, and `Bindings.xml`.
4. Enable **Xius Marks Bar** and `/reload`.

If you downloaded the repository ZIP instead, rename the extracted `XiusMarksBar-main` folder to `XiusMarksBar`.

Raid markers follow normal game rules. In a raid you need to be leader or assistant to place world markers and start a ready check.

**Compatibility:** Modern retail (TOC `120000`–`120107`), World of Warcraft Forever (TOC `16000`–`16001`), and Camelot. Pure Lua 5.1 with no libraries.

## File Overview

| File | Purpose |
| --- | --- |
| `XiusMarksBar.toc` | Addon manifest (interface versions, saved variables, load order) |
| `Config.lua` | Saved settings, options page, key binds, and slash commands |
| `Core.lua` | Marks bar, secure expand logic, mark buttons, pull timers, ready check, and role check |
| `Flywheel.lua` | Radial target-mark and world-marker wheels |
| `Bindings.xml` | Key binding names for the wheels and every mark |

## More From Xius

**Xius Threat Meter**: A clean, lightweight threat meter. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.
[GitHub](https://github.com/XiusTV/XiusThreatMeter) · [CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter)

**Xius XP & Reputation Tracker**: A compact HUD card that replaces the default XP and reputation bars with a single movable panel: level, XP, rested, watched faction, session rates, gold, and time-to-level.
[GitHub](https://github.com/XiusTV/XiusXPTracker) · [CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)

**Xius Max Graphics**: Pick-and-choose graphics upgrades for Forever and retail. Ultimate, Balance, and Defaults presets push view distance, grass, shadows, water, and image clarity past the normal graphics menu, with optional loot and gathering sparkles.
[GitHub](https://github.com/XiusTV/XiusMaxGFX)

**Xius Kill Streak**: A ten-tier kill streak announcer for mobs and enemy players. Each new tier shows a banner and plays a call, with a small counter for the current streak and the time left to keep it going.
[GitHub](https://github.com/XiusTV/XiusKillStreak)

All Xius addons share the same clean, dark gold style for a unified UI.

## License

Released under the [GNU General Public License v3.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and secure frame logic, with manual architecture, in-game verification, and maintenance by Xius.
