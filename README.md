# Nightreign Modpack

One-file installer for an **ELDEN RING NIGHTREIGN** mod set. Everything is loaded through Mod Engine 3;
the game's own files are never changed.

| Mod | What it does |
|---|---|
| [ELDEN VINS NIGHTREIGN](https://www.nexusmods.com/eldenringnightreign/mods/287) | overhaul: skins, animations, balance, its own online server |
| [EVN Russian](https://www.nexusmods.com/eldenringnightreign/mods/447) | Russian texts for Elden Vins, merged into Vins 1.5.2 |
| [Seamless Co-op](https://www.nexusmods.com/eldenringnightreign/mods/3) + Russian translation | co-op for up to 6 players |
| [Unlock The FPS](https://www.nexusmods.com/eldenringnightreign/mods/25) | removes the 60 FPS cap |
| [Adjust The FOV](https://www.nexusmods.com/eldenringnightreign/mods/119) | camera field of view |
| [Mod Engine 3 Manager](https://github.com/2Pz/me3-manager) | GUI for managing me3 mods by hand |

## Install

1. Download **[install.bat](https://github.com/takeshilp/Nightreign-Modpack/releases/latest/download/install.bat)**.
2. Put it into an empty folder on a drive with about 15 GB free, e.g. `D:\Games\Nightreign-Modpack`.
   Not the game folder, not Downloads, not OneDrive.
3. Run it. It updates itself from this repository, then shows the mod list (all on by default).

The installer fetches everything itself:

- Mod Engine 3 and ME3 Manager from their GitHub releases; Elden Vins, its Russian patch and Seamless Co-op from
  the pack's cloud copy; Unlock The FPS / Adjust The FOV from this repository. Downloads are checked against
  SHA-256 and resume after an interruption.
- **The Russian translation of Seamless Co-op comes from Nexus Mods** (also anything the cloud refuses to give).
  The installer opens the page: click *Manual download* → *Slow download* (a free Nexus account is needed).
  It picks the file up from your Downloads folder by itself.

Requirements: ELDEN RING NIGHTREIGN from Steam, Windows 10 or 11, Steam running.

### Controls

| Key | Action |
|---|---|
| `↑` / `↓` | move |
| `Enter` / `Space` | toggle a mod, choose, edit a setting |
| `Delete` | switch an optional setting off |
| `Backspace` | back |
| `Esc` | quit |

## Play

Use the desktop shortcuts:

- **NIGHTREIGN Seamless Co-op** — Elden Vins + Seamless Co-op. Friends join through a Steam invite or
  *Invite Members* in the game's matchmaking settings; the mod has no password of its own.
- **NIGHTREIGN Elden Vins онлайн** — Elden Vins with its own online server (matchmaking with other Vins players).

The *Play* button in Steam starts the game without mods. Everyone playing together needs the same mods and versions.

Saves are kept apart: Seamless Co-op uses `NR0000.co2`, the Vins server `NR0000.CL_SAVE`
(in `%APPDATA%\Nightreign`). To carry progress over, copy the file under the other name. Back the folder up first.

## Settings, update, repair, removal

- `settings.bat`: enemy scaling in co-op, save file extension, FPS limit, FOV, the Vins server room name.
  Close the game first.
- `install.bat` again: change the mod set or repair the installation (settings are kept), open the settings, or
  remove everything the pack installed (saves are not touched).
- `mods\` holds the downloaded archives; it can be deleted after installing, a repair downloads them again.

## Credits and licenses

The mods belong to their authors: Elden Vins, EVN Russian, Seamless Co-op (Yui), the Seamless Co-op Russian
translation, Unlock The FPS and Adjust The FOV (Loukious, after techiew), Mod Engine 3 (Gary Tierney),
ME3 Manager (2Pz). Unlock The FPS and Adjust The FOV are shipped here under their MIT licenses (`licenses\`).
The installer scripts are MIT-licensed (`LICENSE`). Menu style after
[H0oxy's Dark Souls II modpack](https://github.com/H0oxy/Dark-Souls-2-seamless-co-op-Quality-of-life-modpack).
