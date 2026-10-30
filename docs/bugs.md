# Pitfalls

## Elden Vins 1.5.2 profile references a missing DLL

- Symptom: `ELDEN VINS NIGHTREIGN.me3` lists `mod/dll/nighter.dll`; the archive has only `nighter.json`.
- Cause: stale profile in the mod archive. It also says `game = "nightrein"`; me3 0.13 accepts that spelling.
- Fix: `install.ps1` writes its own profiles without `nighter.dll` (the Vins one is not extracted); launch uses `-g nightreign`.
- Verified: `unzip -Z1` of `ELDEN VINS NIGHTREIGN-287-1-5-2-1769916199.zip`; `me3 profile show --file <profile>`
  parses the generated profiles. `profile show` does not check that DLLs exist.

## Vins server redirector vs Seamless Co-op

- Symptom: none observed; its `ReadMe - CustomServerRedirector.txt` says "Can I use this with seamless? No."
- Fix: two profiles. `Seamless Co-op.me3` loads `nrsc.dll` without `cl_server_redirector.dll`, `start_online = false`.
  `Elden Vins online.me3` loads the redirector, `start_online = true` (as Vins ships it).

## Seamless Co-op: "Method SignIn is not available"

- Symptom: on launch, "Seamless Coop 1.1.3 - Fatal Error: Method "SignIn" is not available. If you're using
  ModEngine, please make sure seamless co-op is loaded early." The game exits.
- Cause: `nrsc.dll` was a regular native; the me3 log showed `load_early: false`, `early_natives: []`.
  The profile ME3 Manager generated has the same problem.
- Fix: `load_early = true` on the `nrsc.dll` native (`New-Profile` in `install.ps1`).
- Verified: the user launched the game with the fix. me3 0.13 knows the key (it rejects `load_early = "yes"` with a
  type error; unknown keys are silently ignored, so a typo would not be caught).

## Duplicate FPS/FOV DLLs

- Vins ships `mod/dll/NightreignFPSFOV.dll` (FPS + FOV, own `config.ini`). Loading it together with
  UnlockTheFps/AdjustTheFov would patch the same values twice, so the profiles load only the two standalone mods.

## Vins skins need `_l` duplicates

- Vins' `OPEN-THIS-TO-INSTALL-SKINS.bat` copies every `X.partsbnd.dcx` under `mod/parts` to `X_l.partsbnd.dcx`
  (362 files, 4.5 GB), waits for a key and moves itself to the Recycle Bin.
- Fix: `install.ps1` does the same with hard links (copy fallback); only the `mod` folder of the archive is extracted.

## me3 installed by ME3 Manager has no `.me3` file association

- Symptom: double-clicking a `.me3` profile does nothing; `me3` is not in PATH.
- Cause: the Manager installs a portable me3 to `%LOCALAPPDATA%\garyttierney\me3\bin`.
- Fix: desktop shortcuts run `me3.exe launch -g nightreign -p <profile>` from that folder (falls back to PATH).

## EVN Russian 1.3 does not fit Vins 1.5.2 as shipped

- Symptom: EVN ships `msg/rusru/item.msgbnd.dcx` and `menu.msgbnd.dcx`; Vins 1.5.2 ships only `*_dlc01.msgbnd.dcx`.
- Cause: EVN was made before the DLC. After it, `item_dlc01`/`menu_dlc01` hold every FMG (base ones plus `_dlc01`),
  so the game most likely never reads EVN's base files; if it did, they would replace newer official Russian text.
- Fix: `tools/merge_evn_ru.py` copies EVN lines into Vins' rusru `*_dlc01` files only where Vins has English text
  and the numbers in both texts match (Vins rebalanced since; 18 lines skipped). Result for 1.5.2: 413 item and
  80 menu lines. `install.ps1` applies the zip only when its version matches the Vins zip name.
- Verified: an independent decoder shows exactly 413 + 80 changed entries, all English -> Russian, everything else
  identical. The user ran the game with it.

## FromSoftware file writers: no trailing padding

- BND4 data and FMG files end right after the last file or string, without alignment; DCX files are padded to 16.
  `merge_evn_ru.py` asserts that it rebuilds the untouched Vins files byte for byte before writing anything.

## Re-hosting the mods

- Seamless Co-op's author forbids redistribution (H0oxy's DS2 pack downloads it from `yuiamoroll/*SeamlessCoopRelease`
  for that reason). `yuiamoroll/NightreignSeamlessCoopRelease` has no releases, only files the mod reads itself
  (`VERSION`: `>1.13` marks the current one), so for Nightreign the zip comes from Nexus only.
- me3 has official GitHub releases (`me3_installer.exe` with a sha256 digest in the API). UnlockTheFps and
  AdjustTheFov have MIT sources (`Loukious/NightreignUnlockTheFps`, `Loukious/NightreignAdjustTheFov`), no releases.
- ME3 Manager has official GitHub releases too (`2Pz/me3-manager`, MIT); its Windows zip is byte-identical to the Nexus file.
- Elden Vins and EVN Russian: permissions unknown (Nexus pages return 403 to tools). The owner chose to host Vins,
  the merged Russian patch and (2026-10-31) Seamless Co-op with its translation on Google Drive for friends only,
  and took responsibility for the authors' permission. Those Drive zips are byte-identical to the Nexus files
  4199 and 4319.
- The Seamless Russian translation is Nexus mod 775 (confirmed by the owner).

## Unlock The FPS / Adjust The FOV ignore their config.ini under me3

- Symptom: FPS limit 120 in settings, 200 in game; FOV changes did nothing.
- Cause: both mods (Loukious' forks of techiew's mods, `ModUtils.h`) read `"mods\\" + <dll name> + "\\config.ini"`,
  relative to the process working directory. me3's launcher starts the game with the working directory set to
  the game folder (`crates/launcher/src/main.rs`: `args.exe.parent()`), where no `mods\` exists, so the mods used
  their defaults: FPS limit 300, FOV 48 (the game's own). The ME3 Manager profile had the same problem.
- Fix: `Update-ModLinks` puts junctions `<game>\mods\UnlockTheFps` and `<game>\mods\AdjustTheFov` pointing at the
  folders in `installed\`; removed with the mod or the pack, real folders of that name are left alone, an empty
  `mods\` is deleted. The FOV hint now says the game default is 48 (the shipped config's 60 is already wider).
- Verified: test with a fake game folder. In game: after a launch, `installed\UnlockTheFps\log.txt` should appear
  (written through the junction) with `FPS limit: <value>`.

## me3 not found after its official installer

- Symptom: on a player's PC the pack asked to install me3 on every run, though me3 was installed (into the pack's
  folder, `S:\games\eldanght\me3`); the shortcuts were never created.
- Cause: `Find-Me3` looked only in `%LOCALAPPDATA%\garyttierney\me3` (ME3 Manager's portable install) and on the
  process PATH. The official installer (`installer.nsi` in the me3 repo, v0.13.0) defaults to
  `%LOCALAPPDATA%\Programs\garyttierney\me3`, shows a folder page, records the folder in
  `HKCU\Software\garyttierney\me3\Install_Dir` and adds `bin` to the user PATH, which a running process does not see.
- Fix: `Find-Me3` also reads `Install_Dir`. `Install-Me3` no longer runs the installer: it unpacks `bin\` of the
  release's `me3-windows-amd64.zip` (same three files as ME3 Manager's install) into `%LOCALAPPDATA%\garyttierney\me3`.
- Verified: with a temporary `Install_Dir` pointing at a fake me3, `Find-Me3` returned it (key removed afterwards);
  `Install-Me3` into an empty LOCALAPPDATA downloaded the zip, and the unpacked `me3.exe --version` printed 0.13.0.

## Nexus names browser downloads its own way

- Symptom: a player downloaded Seamless Co-op and its translation from Nexus, even put them into `mods\`, and the
  installer kept waiting ("Жду файлы...").
- Cause: archives were found by file name (`Seamless Co-op (Nightreign)-*.zip`, the names Vortex/ME3 Manager use),
  but a browser download is named `Nightreign Seamless Co-op v1.1.3 3 1.13 2026-07-02T16-30Z zFdpCI7GR.zip`,
  `Russian 775 1 2026-07-23T19-42Z 60hdUAE7y.zip`.
- Fix: `Find-Archive` recognises an archive by an entry inside it (`Has`, plus `Text` for the translation's
  `YUINEXUS` keys, which Elden Ring's Seamless lacks). The Vins patch is tied to the Vins zip by size (`VinsSize`),
  not by its name. Opening a zip reads only its directory: all lookups take ~0.2 s, the 6 GB Vins zip included.
- Verified: test with the Nexus names and with look-alikes (Elden Ring Seamless, another russian.json); real
  archives in `mods\` and `D:\1Downloads\NexusMods` recognised.

## Google Drive downloads

- Files over ~100 MB come back as a "can't scan for viruses" HTML page; its hidden form fields (`id`, `export`,
  `confirm`, `uuid`) make the real link on `drive.usercontent.google.com/download`. Small files come straight away.
- A page without the form means the download quota is exceeded or the file is not shared by link; Vins then falls
  back to Nexus.
- Verified 2026-10-28 with the owner's uploads: the Vins zip (5.9 GB) came through the warning page, 886 s at
  6.8 MB/s, SHA-256 matched; the 0.4 MB patch came straight away. While curl writes, Explorer and Get-ChildItem show
  the `.part` as 0 bytes; open the file to see its real size.

## Windows PowerShell 5.1 and script encoding

- `powershell -File install.ps1` reads a BOM-less UTF-8 script as ANSI and garbles the Russian strings.
  `install.ps1` and the test are saved as UTF-8 with BOM.

## Test regexes vs CRLF

- Symptom: a test check failed while the menu showed the new value.
- Cause: `[IO.File]::WriteAllText` keeps the file's CRLF; `(?m)...$` does not match before `\r`.
- Fix: patterns end with `\r?$`. Verified: test prints `OK`.
