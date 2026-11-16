# Xius Marks Bar

A compact raid marking bar for **modern World of Warcraft** and **World of Warcraft Forever**. Click the **flag** for world markers, click the **star** for target markers, or double-click a unit or the ground to open a mark wheel. Pull timers, ready check, and role check stay on the bar.

Settings open inside [Xius Core](https://github.com/XiusTV/XiusCore). The bar is meant to sit quietly next to the default action bars: near-black slots, thin muted gold borders, and a see-through dark background.

## Features

### Click-to-expand marking

- **Flag:** All 8 world markers plus Clear All. Left-click places or removes a marker. Right-click removes it.
- **Star:** All 8 raid target icons plus Clear Mark. Left-click marks your target. Click the same mark again, or right-click, to clear it.
- **One row at a time:** Opening one row closes the other. Click the open icon again to collapse.
- **Works in combat:** Opening, closing, and marking stay available mid-fight.
- **Show only what you use:** The star, the flag, and each countdown can be hidden from the Marks page in Xius Core.

### Mark wheel

- **Double-click a unit** (mob, player, nameplate, or unit frame) to open a target-mark wheel on your cursor.
- **Double-click the ground** to open a world-marker wheel.
- **Optional modifier:** Shift, Alt, or Ctrl + double-click. Plain double-click stays the default.
- **In combat,** use a key binding. The double-click gesture is outside combat only.
- **Right-click or Escape** closes the wheel. Choosing a mark closes it too.

### Group tools

- **Pull timers (5 / 10 / 20):** Starts the group countdown when you are allowed to, otherwise a chat countdown that ends in "GO!". Click the same button again, or right-click, to cancel.
- **Ready check:** Leader or assistant only.
- **Role check:** Asks everyone to choose a role.

### Bar

- **Blends in:** Near-black slots with thin muted gold borders. Borders warm up on hover or while a row is open.
- **Small footprint:** The bar wraps the buttons that are turned on, then grows only when a mark row is open.
- **Smart growth:** Grows toward the middle of the screen, or always up, or always down.
- **Out-of-the-way tooltips:** Tooltips sit above or below the whole bar.
- **Pixel-snapped:** The bar stays where you placed it when you resize it or the UI scale changes.
- **Key bindings:** Every mark, both clears, and both wheels can be bound. Nothing is bound until you choose a key.
- **Unlock Frames:** `/xius unlock`, or right-click the Xius Core minimap button, shows a drag overlay on the bar. Locking saves its position and hides the overlay.

## Controls & Slash Commands

| Command / Input | Action |
| --- | --- |
| `/xmb` | Open the Marks page in Xius Core |
| `/xmb config` or `/xmb options` | Open the Marks page in Xius Core |
| `/xmb lock` / `/xmb unlock` | Lock or unlock bar movement |
| `/xmb reset` | Move the bar back above the action bar |
| `/xmb collapse` or `/xmb hide` | Close the open mark row |
| `/xmb scale 60-160` | Set the bar size |
| `/xmb help` | List the commands |
| `/xius marks` | Open the Marks page in Xius Core |
| Left-click the flag or the star | Open or close world or target marks |
| Right-click the flag, star, or grip | Open the Marks page |
| Drag the grip | Move the bar when it is unlocked |
| Left-click a countdown | Start that pull. Click again to cancel |
| Right-click a countdown | Cancel the pull |

## Configuration

Open settings with `/xmb` or `/xius marks`. Xius Core has to be installed. The Marks page covers:

- **Bar:** Show the bar, lock position, visibility, and tooltips.
- **Marks on the bar:** Show or hide the star and the flag.
- **Countdown:** Show or hide 5, 10, and 20 separately.
- **Group checks:** Ready check and role check.
- **Mark wheel:** Unit wheel, world-marker wheel, and the double-click modifier.
- **Expand direction:** Auto, always up, or always down.
- **Size:** 60% to 160%.

Settings are saved for the account.

## More From Xius

### Xius Core - [GitHub](https://github.com/XiusTV/XiusCore) · [CurseForge](https://www.curseforge.com/wow/addons/xius-core)

The settings and quality-of-life hub for the Xius addons. One window holds Quality of Life, General, account gold, and every other Xius addon you have installed.

### Xius Threat Meter - [GitHub](https://github.com/XiusTV/XiusThreatMeter) · [CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter)

A threat meter. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.

### Xius XP & Reputation Tracker - [GitHub](https://github.com/XiusTV/XiusXPTracker) · [CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)

A HUD card for level, XP, rested XP, watched faction, session rates, gold, and time-to-level.

### Xius Max Graphics - [GitHub](https://github.com/XiusTV/XiusMaxGFX) · [CurseForge](https://www.curseforge.com/wow/addons/xius-max-graphics)

Graphics presets for Forever and retail. Ultimate, Balance, and Defaults raise view distance, grass, shadows, water, and image clarity, with optional loot and gathering sparkles.

### Xius Kill Streak - [GitHub](https://github.com/XiusTV/XiusKillStreak) · [CurseForge](https://www.curseforge.com/wow/addons/xius-kill-streak)

A ten-tier kill streak announcer for mobs and enemy players. Each tier shows a banner, plays a call, and keeps a counter for the streak and the time left.

Their settings open from Xius Core.

## License

Released under the [GNU General Public License v3.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and secure frame logic, with manual architecture, in-game verification, and maintenance by Xius.
