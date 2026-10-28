# Nightreign modpack

Installer for an ELDEN RING NIGHTREIGN mod set, all loaded through Mod Engine 3 (me3):
Elden Vins (Nexus 287) + EVN Russian (447), Seamless Co-op (3) + its Russian translation, UnlockTheFps (25),
AdjustTheFov (119), Mod Engine 3 Manager. Published at github.com/takeshilp/Nightreign-Modpack; players download
only `install.bat` from the latest release. UI style follows H0oxy's DS2 Seamless Co-op modpack installer.

## Layout

- `install.bat`: bootstrap (batch/PowerShell polyglot). Pulls `install.ps1`, `settings.bat`, `README.md`, `LICENSE`,
  `licenses/` and `mods/` from the repo's `main` branch, then runs `install.ps1`. Skipped when `.git` is next to it.
- `install.ps1`: checklist, getting the archives (`$sources`), install, settings editor, removal, me3 profiles,
  desktop shortcuts. UTF-8 with BOM.
- `settings.bat`: `install.ps1 -Settings only`.
- `mods/`: archives. In git only the MIT ones (UnlockTheFps, AdjustTheFov); locally also hard links to
  `D:\1Downloads\NexusMods` and the built Russian patch.
- `installed/`: install output, rebuilt from scratch on every install; settings ini values carry over.
- `tools/merge_evn_ru.py`: builds `mods/EVN Russian for ELDEN VINS <ver>.zip` (EVN lines merged into Vins' rusru `*_dlc01` files).
- `tests/test-modpack.ps1`: end-to-end test on fake archives, no network; menus driven through `$global:TestKeys`.

## Where the archives come from (`$sources` in install.ps1)

- me3: the portable `me3-windows-amd64.zip` from its GitHub release, `bin\` unpacked into
  `%LOCALAPPDATA%\garyttierney\me3` (where ME3 Manager puts it). Found there, via the official installer's
  `HKCU\Software\garyttierney\me3\Install_Dir`, or on PATH.
- ME3 Manager: GitHub release. Every GitHub download is checked against the API's sha256 digest.
- Elden Vins and the Russian patch: the owner's Google Drive (file id + SHA-256 pinned); empty id or a Drive failure
  falls back to Nexus for Vins and skips the patch.
- Seamless Co-op and its translation: Nexus by hand (redistribution forbidden); picked up from the Downloads folder.

## Commands

- Test: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-modpack.ps1` (prints `OK`; game must be closed).
- Rebuild the Vins Russian patch after a Vins or EVN update: `python -I tools\merge_evn_ru.py` (needs the game installed for Oodle).

## Updating Elden Vins

1. Put the new Vins zip into `mods/`, run `tools\merge_evn_ru.py`.
2. Upload both zips to Google Drive (anyone with the link), put their file ids, names and SHA-256 into `$sources`,
   and the new Vins zip's size into `evn.VinsSize`.
3. Run the test, commit, push to `main`: players get it on their next `install.bat` run.

## Rules

- `install.ps1` and the test stay UTF-8 **with BOM** (Windows PowerShell 5.1 reads BOM-less scripts as ANSI).
  `install.bat` is UTF-8 without BOM (cmd), ASCII before `#>`; all .bat files CRLF.
- Never touch game files: everything lives in `installed/`, the game is launched by me3 through the desktop shortcuts.
- Do not commit Nexus-only archives (see `docs/bugs.md`, "Re-hosting the mods").
- `install.bat` cannot update itself (cmd is reading it while it runs); changes to it reach players only through a new release asset.

## Docs

- `docs/bugs.md`: verified pitfalls of this mod set and of the installer.
