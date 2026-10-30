# End-to-end test of install.ps1 on fake mod archives in a temp folder: checklist, archives picked up from Downloads,
# install, settings editor, reinstall with fewer mods (settings kept), Russian patch without Vins or for another
# Vins version, removal. No network: every archive is already in mods\ or in the fake Downloads.
$ErrorActionPreference = 'Stop'
$t =Join-Path $env:TEMP "nrpack-test-$(Get-Random)"
$pack = "$t\pack"; $root = "$pack\installed"; $desk = "$t\desktop"; $dl = "$t\downloads"

function Fake($dir, $zipName, [hashtable]$files) {
    $d = "$t\src\$zipName"
    foreach ($f in $files.Keys) { New-Item -ItemType File -Force -Path "$d\$f" -Value $files[$f] | Out-Null }
    & tar.exe -a -cf "$dir\$zipName" -C $d @((Get-ChildItem $d).Name)
}
function Check($cond, $msg) { if (-not $cond) { throw "FAIL: $msg" } }
function Text($p) { [IO.File]::ReadAllText($p) }
function Keys { $global:TestKeys = New-Object Collections.Queue; foreach ($k in $args) { $global:TestKeys.Enqueue([string]$k) } }
function Pack { & "$pack\install.ps1" @args 6>$null }   # 6>: Write-Host output is not needed here
function Ini($rel, $line) { (Text "$root\$rel") -match "(?m)^$([regex]::Escape($line))\r?$" }

New-Item -ItemType Directory -Force "$pack\mods", $desk, $dl | Out-Null
Copy-Item (Join-Path $PSScriptRoot '..\install.ps1') $pack
New-Item -ItemType File -Force "$t\appdata\garyttierney\me3\bin\me3.exe" | Out-Null   # fake me3: no download prompt
$appData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = "$t\appdata"
$global:TestDesktop = $desk
$global:TestDownloads = $dl
$game = "$t\game"; $global:TestGameDir = $game
New-Item -ItemType File -Force "$game\mods\SomeoneElse\x.txt" | Out-Null   # another tool's folder: must survive
function Linked($name) {   # a junction in the game's mods\ that leads to the installed copy
    $i = Get-Item -LiteralPath "$game\mods\$name" -Force -ErrorAction SilentlyContinue
    $i -and ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Text "$game\mods\$name\config.ini") -eq (Text "$root\$name\config.ini")
}
try {
    $vinsZip = 'ELDEN VINS NIGHTREIGN-287-1-5-2-1.zip'
    Fake "$pack\mods" $vinsZip @{
        'ELDEN VINS NIGHTREIGN\ELDEN VINS NIGHTREIGN.me3'            = 'original'
        'ELDEN VINS NIGHTREIGN\mod\regulation.bin'                   = 'params'
        'ELDEN VINS NIGHTREIGN\OPEN-THIS-TO-INSTALL-SKINS.bat'       = 'x'
        'ELDEN VINS NIGHTREIGN\mod\msg\rusru\item_dlc01.msgbnd.dcx'  = 'vins-text'
        'ELDEN VINS NIGHTREIGN\mod\parts\wp_a.partsbnd.dcx'          = 'skin-a'
        'ELDEN VINS NIGHTREIGN\mod\parts\sub\am_b.partsbnd.dcx'      = 'skin-b'
        'ELDEN VINS NIGHTREIGN\mod\dll\cl_server_redirector.dll'     = 'x'
        'ELDEN VINS NIGHTREIGN\mod\dll\cl_server_redirector.ini'     = "[cl_server_redirector]`r`n;The URL to the custom server`r`nCL_SERVER_URL=https://x`r`n;CL_CUSTOM_SHARD_NAME=VINS`r`nCL_USE_ALT_SAVE=true"
        'README - INSTALL INSTRUCTIONS.txt'                          = 'readme'
    }
    Fake "$pack\mods" 'EVN Russian for ELDEN VINS 1-5-2.zip' @{ 'msg\rusru\item_dlc01.msgbnd.dcx' = 'merged-ru' }
    Fake "$pack\mods" 'UnlockTheFps-25-1.zip' @{ 'UnlockTheFps.dll' = 'x'; 'UnlockTheFps\config.ini' = "[unlockthefps]`r`nlimit = 120" }
    Fake "$pack\mods" 'AdjustTheFov-119-1.zip' @{ 'AdjustTheFov.dll' = 'x'; 'AdjustTheFov\config.ini' = "[fov]`r`nvalue = 60" }
    Fake "$pack\mods" 'Me3_Manager_1.5.2_Windows.zip' @{ 'Me3_Manager_1.5.2\Me3_Manager.exe' = 'x' }
    # Seamless under the name pinned in $sources (as a Drive download leaves it), and a newer copy of another version
    # left in mods\ earlier: the pinned one must win, or an update on Drive never reaches the player
    foreach ($z in @{ 'Seamless Co-op (Nightreign)-4199.zip' = 'pinned'; 'Seamless Co-op (Nightreign)-1234.zip' = 'other-version' }.GetEnumerator()) {
        Fake "$pack\mods" $z.Key @{
            'nrsc_launcher.exe' = 'x'; 'SeamlessCoop\nrsc.dll' = $z.Value; 'SeamlessCoop\locale\english.json' = '{}'
            'SeamlessCoop\nrsc_settings.ini' = "[SCALING]`r`nhealth_scaling = 100`r`n;Use any alphanumeric characters (limit = 120)`r`nsave_file_extension = co2"
        }
    }
    (Get-Item -LiteralPath "$pack\mods\Seamless Co-op (Nightreign)-1234.zip").LastWriteTime = (Get-Date).AddMinutes(1)
    # The patch fits only the Vins zip it was built from, recognised by size: point it at the fake one. The copy also
    # has no Drive ids (no network here) and no "close the game" check, so the test runs while the real game is open
    # (it touches only temp folders)
    $ps1 = "$pack\install.ps1"
    $code = [IO.File]::ReadAllText($ps1) -replace 'VinsSize = \d+', "VinsSize = $((Get-Item -LiteralPath "$pack\mods\$vinsZip").Length)" -replace "Drive = '[^']*'", "Drive = ''" -replace '(?m)^if \(Get-Process nightreign.*$', ''
    [IO.File]::WriteAllText($ps1, $code, (New-Object Text.UTF8Encoding $true))
    # Nexus-only mods named the way Nexus names browser downloads, a Firefox placeholder of an unfinished download,
    # and look-alikes that must not be taken: Elden Ring's Seamless Co-op and someone else's russian.json
    $coopZip = 'Nightreign Seamless Co-op v1.1.3 3 1.13 2026-07-02T16-30Z zFdpCI7GR.zip'; $ruZip = 'Russian 775 1 2026-07-23T19-42Z 60hdUAE7y.zip'
    Fake $dl $coopZip @{
        'nrsc_launcher.exe' = 'x'; 'SeamlessCoop\nrsc.dll' = 'nexus'; 'SeamlessCoop\locale\english.json' = '{}'
        'SeamlessCoop\nrsc_settings.ini' = "[SCALING]`r`nhealth_scaling = 100`r`n;Use any alphanumeric characters (limit = 120)`r`nsave_file_extension = co2"
    }
    Fake $dl $ruZip @{ 'russian.json' = '{ "MODMESSAGE_YUINEXUSPAUSED": "Пауза" }' }
    Fake $dl 'Seamless Co-op v2.0.1.zip' @{ 'SeamlessCoop\ersc.dll' = 'x'; 'russian.json' = '{ "MODMESSAGE_ELDENRING": "x" }' }
    New-Item -ItemType File "$dl\Nightreign Seamless Co-op v1.1.4.zip", "$dl\Nightreign Seamless Co-op v1.1.4.zip.part" | Out-Null
    (Get-ChildItem $dl -Filter '*.zip') | ForEach-Object { $_.LastWriteTime = (Get-Date).AddMinutes(-5) }   # look-alikes are not just older
    (Get-Item -LiteralPath "$dl\Seamless Co-op v2.0.1.zip").LastWriteTime = Get-Date
    $msg = "$root\vins\msg\rusru\item_dlc01.msgbnd.dcx"
    $coopLnk = "$desk\NIGHTREIGN Seamless Co-op.lnk"; $vinsLnk = "$desk\NIGHTREIGN Elden Vins онлайн.lnk"

    # 1. Fresh install from the checklist: everything is on by default, the Manager gets switched off
    Keys DownArrow DownArrow DownArrow DownArrow DownArrow Enter DownArrow Enter
    Pack -Settings skip
    foreach ($p in "$root\SeamlessCoop\nrsc.dll", "$root\SeamlessCoop\locale\russian.json", "$root\UnlockTheFps.dll",
        "$root\AdjustTheFov\config.ini", "$root\vins\dll\cl_server_redirector.ini", $coopLnk, $vinsLnk, "$pack\mods\$ruZip") {
        Check (Test-Path -LiteralPath $p) "missing $p"
    }
    Check ((Text "$root\SeamlessCoop\nrsc.dll") -eq 'pinned' -and -not (Test-Path -LiteralPath "$pack\mods\$coopZip")) 'pinned file wins over a newer download'
    Check (-not (Test-Path -LiteralPath "$pack\mods\Nightreign Seamless Co-op v1.1.4.zip") -and -not (Test-Path -LiteralPath "$pack\mods\Seamless Co-op v2.0.1.zip")) 'unfinished download and look-alikes ignored'
    Check ((Text "$root\SeamlessCoop\locale\russian.json") -match 'YUINEXUS') 'the right russian.json'
    Check (-not (Test-Path "$root\Me3_Manager_1.5.2")) 'Manager switched off in the checklist'
    Check (-not (Test-Path "$root\nrsc_launcher.exe") -and -not (Test-Path "$root\vins\OPEN-THIS-TO-INSTALL-SKINS.bat")) 'only mod folders extracted'
    Check ((Text "$root\vins\parts\wp_a_l.partsbnd.dcx") -eq 'skin-a' -and (Text "$root\vins\parts\sub\am_b_l.partsbnd.dcx") -eq 'skin-b') 'skin copies'
    Check ((Text $msg) -eq 'merged-ru') 'Vins Russian patch installed'
    Check ((Linked 'UnlockTheFps') -and (Linked 'AdjustTheFov')) 'FPS/FOV configs reachable from the game folder'
    Check (Ini 'modpack.txt' 'mods = vins evn coop fps fov') 'marker'
    $coop = Text "$root\Seamless Co-op.me3"; $vins = Text "$root\Elden Vins online.me3"
    Check ($coop -match 'source = "vins"' -and $coop -match 'start_online = false' -and $coop -notmatch 'cl_server_redirector') 'seamless profile'
    Check ($coop -match '(?s)UnlockTheFps\.dll.*AdjustTheFov\.dll.*path = "SeamlessCoop/nrsc\.dll"\r?\nload_early = true') 'seamless natives, nrsc.dll load_early'
    Check ($vins -match 'vins/dll/cl_server_redirector\.dll' -and $vins -match 'start_online = true' -and $vins -notmatch 'nrsc|nighter|NightreignFPSFOV') 'server profile'
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($coopLnk)
    Check ($lnk.TargetPath -eq "$t\appdata\garyttierney\me3\bin\me3.exe" -and $lnk.Arguments -eq "launch -g nightreign -p `"$root\Seamless Co-op.me3`"") 'shortcut runs me3 with the profile'

    # 2. Settings: every value type, invalid input asked again, an optional key switched off and on
    Keys Enter Enter abc 150 DownArrow DownArrow DownArrow Enter co.2 vins Backspace `
         DownArrow Enter Enter 144 Backspace `
         DownArrow Enter Enter '75,5' Backspace `
         DownArrow Enter DownArrow Enter FRIENDS Delete Enter FRIENDS DownArrow Enter Escape
    Pack -Settings only
    Check (Ini 'SeamlessCoop\nrsc_settings.ini' 'health_scaling = 150') 'int, invalid input rejected'
    Check (Ini 'SeamlessCoop\nrsc_settings.ini' 'save_file_extension = vins') 'ext, invalid input rejected'
    Check ((Ini 'UnlockTheFps\config.ini' 'limit = 144') -and (Text "$game\mods\UnlockTheFps\config.ini") -match 'limit = 144') 'fps limit, seen by the mod'
    Check (Ini 'AdjustTheFov\config.ini' 'value = 75.5') 'num with a comma'
    Check (Ini 'vins\dll\cl_server_redirector.ini' 'CL_CUSTOM_SHARD_NAME=FRIENDS') 'optional key switched on'
    Check (Ini 'vins\dll\cl_server_redirector.ini' 'CL_USE_ALT_SAVE=false') 'true/false toggled'
    Check (Ini 'vins\dll\cl_server_redirector.ini' ';The URL to the custom server') 'comments kept'

    # 3. Reinstall with fewer mods: they disappear, the settings of the kept ones stay
    Pack -Mods 'vins,coop,fps' -Settings skip
    Check (Ini 'modpack.txt' 'mods = vins coop fps') 'marker after reinstall'
    Check ((Text $msg) -eq 'vins-text') 'switched-off Russian patch gives the Vins text back'
    Check (-not (Test-Path "$root\AdjustTheFov.dll") -and (Text "$root\Seamless Co-op.me3") -notmatch 'AdjustTheFov') 'switched-off FOV removed'
    Check ((Linked 'UnlockTheFps') -and -not (Test-Path -LiteralPath "$game\mods\AdjustTheFov")) 'FOV link removed, FPS link survives the rebuild'
    Check ((Ini 'UnlockTheFps\config.ini' 'limit = 144') -and (Ini 'SeamlessCoop\nrsc_settings.ini' 'health_scaling = 150')) 'settings kept'
    Check ((Ini 'vins\dll\cl_server_redirector.ini' 'CL_CUSTOM_SHARD_NAME=FRIENDS') -and (Ini 'vins\dll\cl_server_redirector.ini' 'CL_USE_ALT_SAVE=false')) 'server settings kept'

    # 3b. A rebuild that stops half-way (a broken archive: its directory reads fine, unpacking fails after Vins, Seamless
    # and FPS are already back with default settings) loses no settings, and the next run puts them back
    $broken = Copy-Item -LiteralPath "$pack\mods\AdjustTheFov-119-1.zip" "$pack\mods\AdjustTheFov-broken.zip" -PassThru
    $fs = [IO.File]::OpenWrite($broken.FullName); $fs.Write([byte[]](0, 0, 0, 0), 0, 4); $fs.Dispose()   # no local header
    $broken.LastWriteTime = (Get-Date).AddMinutes(2)
    $failed = $false
    try { Pack -Mods 'vins,coop,fps,fov' -Settings skip } catch { $failed = $true }
    Check ($failed -and (Ini 'UnlockTheFps\config.ini' 'limit = 120')) 'the rebuild failed after unpacking defaults'
    Remove-Item -LiteralPath $broken.FullName
    Pack -Mods 'vins,coop,fps' -Settings skip
    Check ((Ini 'UnlockTheFps\config.ini' 'limit = 144') -and (Ini 'SeamlessCoop\nrsc_settings.ini' 'health_scaling = 150') -and
        (Ini 'vins\dll\cl_server_redirector.ini' 'CL_CUSTOM_SHARD_NAME=FRIENDS')) 'settings survive a failed rebuild'
    Check (-not (Test-Path "$pack\settings-backup")) 'settings copies removed after a complete install'

    # 4. The Russian patch needs Vins, and only goes in for the Vins version it was built for
    Pack -Mods 'evn,coop' -Settings skip
    Check (Ini 'modpack.txt' 'mods = coop') 'patch without Vins dropped'
    Check (-not (Test-Path "$root\vins") -and (Text "$root\Seamless Co-op.me3") -notmatch 'packages') 'no Vins package'
    Check ((Test-Path -LiteralPath $coopLnk) -and -not (Test-Path -LiteralPath $vinsLnk)) 'server shortcut removed'
    Check (-not (Test-Path -LiteralPath "$game\mods\UnlockTheFps") -and (Test-Path "$game\mods\SomeoneElse\x.txt")) 'links gone, other folders kept'
    Remove-Item -LiteralPath "$game\mods\SomeoneElse" -Recurse
    # A newer Vins (another size) as Nexus names it
    Fake "$pack\mods" 'ELDEN VINS NIGHTREIGN 287 1.6.0 2026-11-01T10-00Z abc.zip' @{
        'ELDEN VINS NIGHTREIGN\mod\regulation.bin' = 'params 1.6'; 'ELDEN VINS NIGHTREIGN\mod\msg\rusru\item_dlc01.msgbnd.dcx' = 'vins-text'
    }
    (Get-Item -LiteralPath "$pack\mods\ELDEN VINS NIGHTREIGN 287 1.6.0 2026-11-01T10-00Z abc.zip").LastWriteTime = (Get-Date).AddMinutes(1)
    Pack -Mods 'vins,evn' -Settings skip
    Check ((Ini 'modpack.txt' 'mods = vins') -and (Text $msg) -eq 'vins-text') 'patch for another Vins version skipped'
    Check (-not (Test-Path -LiteralPath "$game\mods")) 'empty mods folder removed from the game folder'

    # 4b. No junction possible in the game folder (here "mods" is a file): a warning, the install still completes
    $global:TestGameDir = "$t\game2"
    New-Item -ItemType File -Force "$t\game2\mods" | Out-Null
    Pack -Mods 'fps' -Settings skip
    Check ((Ini 'modpack.txt' 'mods = fps') -and (Test-Path -LiteralPath "$desk\NIGHTREIGN с модами.lnk")) 'install completes without the junction'
    $global:TestGameDir = $game

    # 5. Remove everything through the menu: installed mods, settings and shortcuts go, the archives stay
    Keys DownArrow DownArrow Enter DownArrow Enter
    Pack
    Check (-not (Test-Path $root) -and -not (Test-Path -LiteralPath $coopLnk)) 'removed'
    Check ((Get-ChildItem "$pack\mods").Count -eq 9) 'archives kept'
    $err = $null
    try { Pack -Settings only } catch { $err = "$_" }
    Check ($err -match 'не установлены') 'settings without an installation'

    # 6. Every box unticked (the Vins patch only blocked, still ticked): nothing to install, so nothing happens
    Keys Enter DownArrow DownArrow Enter DownArrow Enter DownArrow Enter DownArrow Enter DownArrow Enter
    Pack -Settings skip
    Check (-not (Test-Path $root) -and -not (Get-ChildItem $desk -Filter '*.lnk')) 'empty choice cancels'
    Write-Host 'OK' -ForegroundColor Green
} finally {
    $env:LOCALAPPDATA = $appData
    Remove-Variable TestKeys, TestDesktop, TestDownloads, TestGameDir -Scope Global -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
}
