# Xius Marks Bar

A compact, lightweight raid marking bar designed for **World of Warcraft Forever (1.60.1)**. Click the **flag** to open world markers, click the **star** to open target markers, and keep your **pull timers**, **ready check**, and **role check** one click away. Near-black slots, thin muted gold borders, and a see-through dark background let it sit quietly alongside the default action bars.

## Features

### 🎯 Click-to-Expand Marking

- **Flag → World Marks:** Opens a row of all 8 world markers plus a *Clear All* button. Left-click places a marker, right-click removes it.
- **Star → Target Marks:** Opens a row of all 8 raid target icons plus a *Clear Mark* button. Left-click marks your target, right-click clears it.
- **One Row at a Time:** Opening one row closes the other. Click the open icon again to collapse back to the compact bar.
- **Works in Combat:** Opening, closing, and marking all work mid-fight.
- **Active Highlight:** The flag or star glows soft gold while its row is open.

### ⏱️ Always-On Group Tools

- **Pull Timers (5 / 10 / 20):** Starts the built-in group countdown, with a chat countdown ending in "GO!" as a fallback.
- **RC (Ready Check):** Starts a ready check for the group.
- **R (Role Check):** Asks everyone to choose a role.

### 🖥️ Clean, Compact Design

- **Blends In:** Near-black slots with thin muted gold borders and softened corners. Borders warm up only on hover or while a row is open.
- **Small Footprint:** A slim single line of 20px buttons until you open a row.
- **Smart Growth:** Grows upward when placed near the bottom of the screen and downward near the top, so the bottom row of buttons never jumps.
- **Out-of-the-Way Tooltips:** Tooltips appear above (or below) the whole bar, never on top of the buttons you're about to click.
- **Pixel-Snapped:** Borders stay crisp and even at any size.

## Display States

- **Collapsed:** Flag • Star • 5 • 10 • 20 • RC • R • Move grip
- **World Marks Open:** Blue Square • Green Triangle • Purple Diamond • Red Cross • Yellow Star • Orange Circle • Silver Moon • White Skull • Clear All
- **Target Marks Open:** Star • Circle • Diamond • Triangle • Moon • Square • Cross • Skull • Clear Mark

## Controls & Slash Commands

| Command / Input | Action |
| --- | --- |
| `/xmb` or `/xiusmarks` | Display slash command help |
| `/xmb config` or `/xmb opt` | Open the AddOn options panel |
| `/xmb lock` / `/xmb unlock` | Lock or unlock bar movement |
| `/xmb reset` | Move the bar back above the action bar |
| `/xmb show` / `/xmb hide` | Open target marks / collapse all rows |
| Left-Click Flag / Star | Open or close world / target marks |
| Right-Click Flag, Star, or Grip | Open options |
| Drag the Grip (`‖`) | Move the bar (when unlocked) |
| Left / Right-Click a Mark | Place / remove that mark |

## Configuration

Access settings via `/xmb config` or **Game Menu → Options → AddOns → Xius Marks Bar**:

- **Bar:** Lock position, only show in a group or instance, show or hide tooltips.
- **Always On The Bar:** Toggle pull timers, ready check, and role check individually.
- **Expand Direction:** `Auto (Screen Position)`, `Always Expand Up`, or `Always Expand Down`.
- **Size:** 60% – 160% scale. The bar stays exactly where you placed it when resizing.
- **Reset Position / Collapse Marks:** Quick buttons to restore defaults.

All settings are saved per account in `XiusMarksBarDB`.

## Installation

1. Download the latest release `.zip` (or use **Code → Download ZIP** on this page).
2. Extract the `XiusMarksBar` folder directly into your client's addon directory: `World of Warcraft Forever\Interface\AddOns`
   - If you downloaded the repository ZIP, rename the extracted `XiusMarksBar-main` folder to `XiusMarksBar`.
3. Verify the folder contains `XiusMarksBar.toc`, `Config.lua`, and `Core.lua`.
4. Launch the game, confirm Xius Marks Bar is checked in your AddOns menu, and run `/reload`.

**Note:** Raid markers follow normal game rules. In a raid you need to be leader or assistant to place marks and start ready checks.

**Compatibility:** Built exclusively for World of Warcraft Forever (TOC `16001`). Pure Lua 5.1 with zero external library dependencies.

## File Overview

| File | Purpose |
| --- | --- |
| `XiusMarksBar.toc` | Addon manifest (interface version, saved variables, load order) |
| `Config.lua` | Default settings, saved variables, options panel, and slash commands |
| `Core.lua` | Marks bar, secure expand logic, mark buttons, pull timers, ready check, and role check |

## More From Xius

**[Xius Threat Meter](https://github.com/XiusTV/XiusThreatMeter)** ([CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter), awaiting approval): A clean, lightweight threat meter for World of Warcraft Forever. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.

**[Xius XP & Reputation Tracker](https://github.com/XiusTV/XiusXPTracker)** ([CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)): A compact HUD card that replaces the default XP and reputation bars with a single movable panel: level, XP, rested, watched faction, session rates, gold, and time-to-level.

Together they make a clean, unified UI.

## License

Released under the [GNU General Public License v3.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and secure frame logic, with manual architecture, in-game verification, and maintenance by Xius.
