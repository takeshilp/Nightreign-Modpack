# ELDEN RING NIGHTREIGN mod pack installer. install.bat: pick mods, install / change / remove, settings.
# settings.bat: settings only. -Mods, -Action, -Settings skip the menus (used by tests\test-modpack.ps1).
param([string[]]$Mods, [ValidateSet('ask', 'only', 'skip')][string]$Settings = 'ask', [ValidateSet('install', 'remove')][string]$Action)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$src = Join-Path $PSScriptRoot 'mods'          # mod archives: shipped, downloaded or picked up from Downloads
$root = Join-Path $PSScriptRoot 'installed'    # everything the pack installs; each install rebuilds it from scratch
$marker = Join-Path $root 'modpack.txt'        # which mods are installed
$nrsc = 'SeamlessCoop/nrsc.dll'
# Test seams: $global:TestDesktop and $global:TestDownloads replace the real folders
$desktop = if ($global:TestDesktop) { $global:TestDesktop } else { [Environment]::GetFolderPath('Desktop') }

# Where each archive comes from. Pattern = file name in mods\ or Downloads, the newest match wins.
# Drive = Google Drive file id of the pack owner's upload, checked against Sha256 (empty: not uploaded, use Nexus);
# GitHub = owner/repo whose latest release has it; Nexus = page the player downloads it from by hand.
# No source at all: shipped in this repository's mods\ (MIT-licensed mods)
$sources = @{
    vins   = @{ Pattern = 'ELDEN VINS NIGHTREIGN-*.zip'; File = 'ELDEN VINS NIGHTREIGN-287-1-5-2-1769916199.zip'; Drive = ''
                Sha256 = '945073D5645BABB68BED8CD514356C05787C19378D9FD2A6C2997706BAEBEF60'
                Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/287?tab=files'; Title = 'ELDEN VINS NIGHTREIGN' }
    # Built by tools\merge_evn_ru.py for one Vins version, so the name is exact
    evn    = @{ Pattern = 'EVN Russian for ELDEN VINS 1-5-2.zip'; File = 'EVN Russian for ELDEN VINS 1-5-2.zip'; Drive = ''
                Sha256 = '8CAB8AE94846B87FB5B7D97D5E6D66ACD5AC54B1CD1B533B8A7EBEE0BD92D8E1' }
    coop   = @{ Pattern = 'Seamless Co-op (Nightreign)-*.zip'; Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/3?tab=files'; Title = 'Seamless Co-op' }
    coopru = @{ Pattern = 'Russian Translation of Seamless Co-op*.zip'; Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/775?tab=files'
                Title = 'Russian Translation of Seamless Co-op' }
    fps    = @{ Pattern = 'UnlockTheFps-*.zip' }
    fov    = @{ Pattern = 'AdjustTheFov-*.zip' }
    mgr    = @{ Pattern = 'Me3_Manager_*_Windows.zip'; GitHub = '2Pz/me3-manager' }
}

# Mods to pick from. Archives = keys of $sources; Needs = mod that has to be on as well
$catalog = @(
    @{ Id = 'vins'; Name = 'ELDEN VINS NIGHTREIGN';      Desc = 'оверхол: скины, анимации, баланс, свой онлайн-сервер'; Archives = 'vins' }
    @{ Id = 'evn';  Name = 'Русский перевод Elden Vins'; Desc = 'тексты Vins, которые остались на английском'; Archives = 'evn'; Needs = 'vins' }
    @{ Id = 'coop'; Name = 'Seamless Co-op';             Desc = 'кооператив до 6 игроков, русский перевод'; Archives = 'coop', 'coopru' }
    @{ Id = 'fps';  Name = 'Unlock The FPS';             Desc = 'снимает лимит в 60 кадров'; Archives = 'fps' }
    @{ Id = 'fov';  Name = 'Adjust The FOV';             Desc = 'угол обзора камеры'; Archives = 'fov' }
    @{ Id = 'mgr';  Name = 'Mod Engine 3 Manager';       Desc = 'программа для ручного управления модами me3'; Archives = 'mgr' }
)
$byId = @{}
foreach ($m in $catalog) { $byId[$m.Id] = $m }

# Settings menu, one screen per mod: key|type|label|hint. Types: int, num, ext (letters and digits), text,
# tf (true/false), opt (text that can be switched off, i.e. commented out with ';')
$settingsTable = @(
    @{ Mod = 'Seamless Co-op'; File = 'SeamlessCoop\nrsc_settings.ini'; Items = @(
        'health_scaling|int|Здоровье врагов в кооперативе, %|100 = как в игре'
        'damage_scaling|int|Урон врагов в кооперативе, %|100 = как в игре'
        'posture_scaling|int|Стойкость врагов в кооперативе, %|100 = как в игре'
        'save_file_extension|ext|Расширение файла сохранения|после смены игра возьмёт другой сейв'
    ) }
    @{ Mod = 'Unlock The FPS'; File = 'UnlockTheFps\config.ini'; Items = @(
        'limit|int|Лимит кадров'
    ) }
    @{ Mod = 'Adjust The FOV'; File = 'AdjustTheFov\config.ini'; Items = @(
        'value|num|Угол обзора (FOV)|в игре по умолчанию 60'
    ) }
    @{ Mod = 'Elden Vins: онлайн-сервер'; File = 'vins\dll\cl_server_redirector.ini'; Items = @(
        'CL_SERVER_URL|text|Адрес сервера'
        'CL_CUSTOM_SHARD_NAME|opt|Своя комната на сервере|подбор только с теми, у кого то же имя, до 16 символов'
        'CL_USE_ALT_SAVE|tf|Отдельный сейв NR0000.CL_SAVE|бережёт основной сейв, лучше не выключать'
    ) }
)

function Find-Me3 {
    $p = "$env:LOCALAPPDATA\garyttierney\me3\bin\me3.exe"
    if (Test-Path -LiteralPath $p) { return $p }
    (Get-Command me3.exe -ErrorAction SilentlyContinue).Source
}

# Only for the shortcut icon: me3 finds the game by itself
function Find-GameExe {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return }
    $libs = @($steam) + @(Select-String -Path "$steam\steamapps\libraryfolders.vdf" -Pattern '"path"\s+"(.+)"' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' })
    foreach ($l in $libs) {
        $exe = Join-Path $l 'steamapps\common\ELDEN RING NIGHTREIGN\Game\nightreign.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
}

# ---------- console menus ----------

# Test seam: $global:TestKeys feeds menu keys and typed values instead of the keyboard
function Read-MenuKey {
    if ($null -ne $global:TestKeys) { return $global:TestKeys.Dequeue() }
    [string][Console]::ReadKey($true).Key
}

function Show-Menu($title, $rows, $sel, $footer, $dim = @()) {
    Clear-Host
    Write-Host $title -ForegroundColor Cyan
    Write-Host ''
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($i -eq $sel) { Write-Host "> $($rows[$i]) " -ForegroundColor Black -BackgroundColor Gray }
        elseif ($dim -contains $i) { Write-Host "  $($rows[$i])" -ForegroundColor DarkGray }
        else { Write-Host "  $($rows[$i])" }
    }
    Write-Host ''
    foreach ($line in @($footer)) { if ($line) { Write-Host $line -ForegroundColor DarkGray } }
}

# Arrow-key list of choices; returns the chosen index, or -1 on Backspace/Esc
function Select-Option($title, $options) {
    $sel = 0
    while ($true) {
        Show-Menu $title $options $sel '↑↓ выбор   Enter подтвердить   Backspace/Esc отмена'
        switch (Read-MenuKey) {
            'UpArrow'   { $sel = ($sel - 1 + $options.Count) % $options.Count }
            'DownArrow' { $sel = ($sel + 1) % $options.Count }
            'Enter'     { return $sel }
            { $_ -in 'Backspace', 'Escape' } { return -1 }
        }
    }
}

# Why a mod cannot be on with this choice, or $null
function Get-Blocker($m, $mods) {
    if ($m.Needs -and $mods -notcontains $m.Needs) { "нужен $($byId[$m.Needs].Name)" }
}

# Mod checklist; returns the chosen ids, or $null when cancelled
function Select-Mods($mods) {
    $sel = 0
    while ($true) {
        $rows = @()
        $dim = @()
        for ($i = 0; $i -lt $catalog.Count; $i++) {
            $m = $catalog[$i]
            $why = Get-Blocker $m $mods
            if ($why) { $rows += "[-] $($m.Name) — $why"; $dim += $i }
            else { $rows += "[$(if ($mods -contains $m.Id) { 'x' } else { ' ' })] $($m.Name) — $($m.Desc)" }
        }
        $rows += '>>> Установить'
        Show-Menu 'Что установить' $rows $sel @('↑↓ выбор   Enter/Пробел включить или выключить',
                                                'Enter на «Установить» начинает установку   Backspace/Esc отмена') $dim
        $key = Read-MenuKey
        switch ($key) {
            'UpArrow'   { $sel = ($sel - 1 + $rows.Count) % $rows.Count }
            'DownArrow' { $sel = ($sel + 1) % $rows.Count }
            { $_ -in 'Backspace', 'Escape' } { return $null }
            { $_ -in 'Enter', 'Spacebar' } {
                if ($sel -eq $rows.Count - 1) { if ($key -eq 'Enter') { return , @($mods) } }
                elseif (-not (Get-Blocker $catalog[$sel] $mods)) {
                    $id = $catalog[$sel].Id
                    if ($mods -contains $id) { $mods = @($mods | Where-Object { $_ -ne $id }) } else { $mods = @($mods) + $id }
                }
            }
        }
    }
}

# ---------- ini files ----------

# Value of a key, or $null; a key commented out with ';' counts as switched off
function Get-IniValue($text, $key) {
    if ($text -match "(?m)^[ \t]*$([regex]::Escape($key))[ \t]*=[ \t]*([^\r\n]*)") { $Matches[1].Trim() }
}

# The key is in the file, on or commented out
function Test-IniKey($text, $key) {
    $text -match "(?m)^[ \t]*;?[ \t]*$([regex]::Escape($key))[ \t]*="
}

# Sets a key and switches it on if it was commented out; $null comments it out
function Set-IniValue($text, $key, $value) {
    [regex]::Replace($text, "(?m)^[ \t]*;?[ \t]*($([regex]::Escape($key))[ \t]*=[ \t]*)([^\r\n]*)", {
        param($m)
        if ($null -eq $value) { ';' + $m.Groups[1].Value + $m.Groups[2].Value } else { $m.Groups[1].Value + $value }
    })
}

# WriteAllText without an encoding writes UTF-8 with no BOM, which the mods' ini parsers expect
function Update-Ini($path, $key, $value) {
    [IO.File]::WriteAllText($path, (Set-IniValue ([IO.File]::ReadAllText($path)) $key $value))
}

# The new ini text with every key the old text also has (on or commented out) taken over from the old text,
# so the player's values survive a reinstall and keys a newer mod version adds still show up
function Merge-Ini($new, $old) {
    [regex]::Replace($new, '(?m)^[ \t]*;?[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[^\r\n]*', {
        param($m)
        if ($old -match "(?m)^[ \t]*;?[ \t]*$($m.Groups[1].Value)[ \t]*=[^\r\n]*") { $Matches[0] } else { $m.Value }
    })
}

function Show-Value($type, $v) {
    if ($null -eq $v) { return 'выкл' }
    if ($type -eq 'tf') { if ($v -eq 'true') { 'да' } else { 'нет' } } else { $v }
}

# Typed values: Enter keeps the current one
function Read-Value($type, $label, $cur) {
    while ($true) {
        $prompt = "`n  $label [$(Show-Value $type $cur)], Enter = оставить"
        $in = "$(if ($null -ne $global:TestKeys) { $global:TestKeys.Dequeue() } else { Read-Host $prompt })".Trim()
        if (-not $in) { return $cur }
        switch ($type) {
            'int' { if ($in -match '^\d+$') { return $in } }
            'num' { $in = $in -replace ',', '.'; if ($in -match '^\d+(\.\d+)?$') { return $in } }
            'ext' { if ($in -match '^[A-Za-z0-9]+$') { return $in } }
            default { return $in }
        }
        Write-Host '    Не понял, попробуй ещё раз.' -ForegroundColor Yellow
    }
}

# One mod's settings screen; returns 'exit' when Esc should close the whole settings menu
function Edit-Mod($s) {
    $path = Join-Path $root $s.File
    $text = [IO.File]::ReadAllText($path)
    $items = @($s.Items | ForEach-Object { $k, $t, $l, $h = $_ -split '\|', 4; [pscustomobject]@{ Key = $k; Type = $t; Label = $l; Hint = $h } } |
        Where-Object { Test-IniKey $text $_.Key })
    if (-not $items) { return }
    $w = ($items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum + 2
    $sel = 0
    while ($true) {
        $text = [IO.File]::ReadAllText($path)
        $it = $items[$sel]
        $cur = Get-IniValue $text $it.Key
        $rows = @($items | ForEach-Object { $_.Label.PadRight($w) + (Show-Value $_.Type (Get-IniValue $text $_.Key)) })
        $how = switch ($it.Type) { 'tf' { 'Enter переключить' } 'opt' { 'Enter ввести значение   Delete выключить' } default { 'Enter ввести значение' } }
        Show-Menu $s.Mod $rows $sel @("↑↓ выбор   $how   Backspace назад   Esc выход", $it.Hint)
        $change = $false
        $new = $null
        switch (Read-MenuKey) {
            'UpArrow'   { $sel = ($sel - 1 + $items.Count) % $items.Count }
            'DownArrow' { $sel = ($sel + 1) % $items.Count }
            'Backspace' { return }
            'Escape'    { return 'exit' }
            'Delete'    { $change = $it.Type -eq 'opt' -and $null -ne $cur }
            'Enter' {
                $new = if ($it.Type -eq 'tf') { if ($cur -eq 'true') { 'false' } else { 'true' } } else { Read-Value $it.Type $it.Label $cur }
                $change = $new -ne $cur
            }
        }
        if ($change) { Update-Ini $path $it.Key $new }
    }
}

function Edit-Settings {
    $sel = 0
    while ($true) {
        $list = @($settingsTable | Where-Object { Test-Path -LiteralPath (Join-Path $root $_.File) })
        if (-not $list) { Write-Host 'Нет установленных модов с настройками.'; return }
        Show-Menu 'Настройки модов' @($list | ForEach-Object Mod) $sel '↑↓ выбор   Enter открыть   Backspace/Esc выход   Изменения сохраняются сразу'
        switch (Read-MenuKey) {
            'UpArrow'   { $sel = ($sel - 1 + $list.Count) % $list.Count }
            'DownArrow' { $sel = ($sel + 1) % $list.Count }
            { $_ -in 'Backspace', 'Escape' } { return }
            'Enter'     { if ((Edit-Mod $list[$sel]) -eq 'exit') { return } }
        }
    }
}

# ---------- getting the archives ----------

function Get-DownloadsDir {
    if ($global:TestDownloads) { return $global:TestDownloads }
    (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
}

# Newest finished file matching the pattern (Firefox keeps an empty placeholder next to a .part while downloading)
function Find-Newest($dir, $pattern) {
    Get-ChildItem -LiteralPath $dir -Filter $pattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 -and -not (Test-Path -LiteralPath "$($_.FullName).part") } |
        Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object FullName
}

# curl ships with Windows 10+, shows progress and resumes an interrupted download from the .part file (-C -)
function Save-Url($url, $dest, $sha) {
    $ErrorActionPreference = 'Continue'   # curl draws its progress on stderr; success is judged by the exit code
    $part = "$dest.part"
    if (-not ($sha -and (Test-Path -LiteralPath $part) -and (Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash -eq $sha)) {
        & curl.exe -L --fail --retry 3 -C - -o $part $url
        if ($LASTEXITCODE) { throw "загрузка прервалась (curl $LASTEXITCODE). Запусти install.bat ещё раз, она продолжится с того же места." }
        if ($sha -and (Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash -ne $sha) {
            Remove-Item -LiteralPath $part
            throw 'скачанный файл не совпал по контрольной сумме. Запусти install.bat ещё раз.'
        }
    }
    Move-Item -LiteralPath $part $dest -Force
}

# Google Drive answers a large file with a "can't scan for viruses" page whose form holds the real download link
function Save-Drive($id, $dest, $sha) {
    $page = "$dest.page"
    & curl.exe -L --fail -s -o $page "https://drive.usercontent.google.com/download?id=$id&export=download"
    if ($LASTEXITCODE) { throw "Google Drive не отвечает (curl $LASTEXITCODE)" }
    $head = [IO.File]::ReadAllBytes($page)
    if ($head.Length -gt 1 -and $head[0] -eq 0x50 -and $head[1] -eq 0x4B) {   # 'PK': a small file comes straight away
        if ($sha -and (Get-FileHash -LiteralPath $page -Algorithm SHA256).Hash -ne $sha) { Remove-Item -LiteralPath $page; throw 'файл не совпал по контрольной сумме' }
        Move-Item -LiteralPath $page $dest -Force
        return
    }
    $html = [Text.Encoding]::UTF8.GetString($head)
    Remove-Item -LiteralPath $page
    $fields = [regex]::Matches($html, '<input type="hidden" name="([^"]+)" value="([^"]*)"')
    if (-not $fields.Count) { throw 'Google Drive не отдал файл: превышена квота скачиваний или нет доступа по ссылке' }
    $query = ($fields | ForEach-Object { "$($_.Groups[1].Value)=$([uri]::EscapeDataString($_.Groups[2].Value))" }) -join '&'
    Save-Url "https://drive.usercontent.google.com/download?$query" $dest $sha
}

# Latest release asset matching the pattern, checked against the SHA-256 GitHub publishes for it
function Save-GitHub($repo, $pattern, $dir) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $a = @((Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -TimeoutSec 20).assets | Where-Object { $_.name -like $pattern })[0]
    if (-not $a) { throw "В последнем релизе $repo на GitHub нет файла $pattern." }
    $dest = Join-Path $dir $a.name
    Save-Url $a.browser_download_url $dest ("$($a.digest)" -replace '^sha256:', '')
    $dest
}

# Path of an archive in mods\, taken from Downloads or downloaded if needed; $null when it has to come from
# Nexus by hand, or (no Nexus page) when it cannot be had at all
function Get-Archive($key) {
    $s = $sources[$key]
    $have = Find-Newest $src $s.Pattern
    if ($have) { return $have }
    $dl = Find-Newest (Get-DownloadsDir) $s.Pattern
    if ($dl) {
        $dest = Join-Path $src (Split-Path -Leaf $dl)
        try { New-Item -ItemType HardLink -Path $dest -Value $dl | Out-Null } catch { Copy-Item -LiteralPath $dl $dest }
        return $dest
    }
    if ($s.Drive) {
        Write-Host "Качаю $($s.File) с Google Drive..."
        try { Save-Drive $s.Drive (Join-Path $src $s.File) $s.Sha256; return Join-Path $src $s.File }
        catch { Write-Host "Google Drive: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if ($s.GitHub) { Write-Host "Качаю $($s.Pattern) с GitHub..."; return Save-GitHub $s.GitHub $s.Pattern $src }
    if (-not $s.Nexus -and -not $s.ContainsKey('Drive')) { throw "Нет архива '$($s.Pattern)' в папке $src" }   # shipped one
}

# Nexus only lets logged-in people download, so the player does it in the browser; the archives are picked up
# from Downloads (or mods\) as soon as they appear there
function Wait-Nexus($keys) {
    $dl = Get-DownloadsDir
    Write-Host "`nЭти моды есть только на Nexus Mods, их нужно скачать вручную (нужен бесплатный аккаунт Nexus):" -ForegroundColor Yellow
    foreach ($k in $keys) { Write-Host "  - $($sources[$k].Title)"; Start-Process $sources[$k].Nexus }
    Write-Host 'Их страницы открыты в браузере: Files > Manual download > Slow download.'
    Write-Host "Установщик сам заберёт архивы из папки «Загрузки» ($dl) или из $src."
    Write-Host 'Жду файлы... Esc = отмена' -ForegroundColor DarkGray
    while (@($keys | Where-Object { -not (Find-Newest $src $sources[$_].Pattern) -and -not (Find-Newest $dl $sources[$_].Pattern) }).Count) {
        if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Escape') { throw 'Установка отменена.' }
        Start-Sleep -Milliseconds 1500
    }
}

# Archives of the chosen mods by $sources key. Everything is fetched before the installation changes
function Get-Archives($mods) {
    [IO.Directory]::CreateDirectory($src) | Out-Null
    $zip = @{}
    $manual = @()
    foreach ($k in @($mods | ForEach-Object { $byId[$_].Archives })) {
        $p = Get-Archive $k
        if ($p) { $zip[$k] = $p } elseif ($sources[$k].Nexus) { $manual += $k }
    }
    if ($manual) { Wait-Nexus $manual; foreach ($k in $manual) { $zip[$k] = Get-Archive $k } }
    $zip
}

# ---------- install / remove ----------

function Expand-Zip($zip, $dest, $member, $strip = 0) {
    $ErrorActionPreference = 'Continue'   # tar reports on stderr; success is judged by the exit code
    [IO.Directory]::CreateDirectory($dest) | Out-Null
    $opts = @('-xf', $zip, '-C', $dest)
    if ($strip) { $opts += '--strip-components', $strip }
    if ($member) { $opts += $member }
    & tar.exe @opts
    if ($LASTEXITCODE) { throw "Не удалось распаковать $(Split-Path -Leaf $zip) (код $LASTEXITCODE). Не хватает места на диске?" }
}

# What Vins' OPEN-THIS-TO-INSTALL-SKINS.bat does (X.partsbnd.dcx -> X_l.partsbnd.dcx), but with hard links
# instead of 4.5 GB of copies
function Add-SkinLinks($parts) {
    foreach ($f in @(Get-ChildItem -LiteralPath $parts -Recurse -File -Filter '*.partsbnd.dcx')) {
        if ($f.Name -like '*_l.partsbnd.dcx') { continue }
        $dst = Join-Path $f.DirectoryName ($f.Name -replace '\.partsbnd\.dcx$', '_l.partsbnd.dcx')
        try { New-Item -ItemType HardLink -Path $dst -Value $f.FullName | Out-Null }
        catch { Copy-Item -LiteralPath $f.FullName -Destination $dst }
    }
}

function Install-Me3 {
    if (Find-Me3) { return }
    $c = Select-Option 'Для запуска модов нужен Mod Engine 3 (me3), он не найден. Скачать официальный установщик с GitHub?' @('Да, скачать и установить', 'Нет')
    if ($c -ne 0) { Write-Host 'Без me3 игра с модами не запустится. Запусти install.bat ещё раз, когда будешь готов.' -ForegroundColor Yellow; return }
    Write-Host 'Качаю установщик me3...'
    $exe = Save-GitHub 'garyttierney/me3' 'me3_installer.exe' $env:TEMP
    Start-Process $exe -Wait
    Remove-Item -LiteralPath $exe
}

function New-Profile($online, $natives, $package) {
    $t = "profileVersion = `"v1`"`r`nstart_online = $("$online".ToLower())`r`n`r`n[[supports]]`r`ngame = `"nightreign`"`r`n"
    if ($package) { $t += "`r`n[[packages]]`r`nid = `"mod`"`r`nsource = `"$package`"`r`n" }
    foreach ($n in $natives) {
        $t += "`r`n[[natives]]`r`npath = `"$n`"`r`n"
        # Seamless aborts with "Method SignIn is not available" unless me3 loads it before the game starts up
        if ($n -eq $nrsc) { $t += "load_early = true`r`n" }
    }
    $t
}

function Remove-OurShortcuts {
    $sh = New-Object -ComObject WScript.Shell
    Get-ChildItem -LiteralPath $desktop -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $sh.CreateShortcut($_.FullName).WorkingDirectory -eq $root } | Remove-Item
}

function Install-Mods($mods) {
    $asked = @($mods)
    $mods = @($catalog | Where-Object { $asked -contains $_.Id -and -not (Get-Blocker $_ $asked) } | ForEach-Object Id)
    $zip = Get-Archives $mods
    if ($mods -contains 'evn') {
        # The patch carries whole Vins text files: on another Vins version it would replace newer Vins texts
        $ver = [regex]::Match((Split-Path -Leaf $zip.vins), '^ELDEN VINS NIGHTREIGN-\d+-(.+)-\d+\.zip$').Groups[1].Value
        if (-not $zip.evn -or (Split-Path -Leaf $zip.evn) -ne "EVN Russian for ELDEN VINS $ver.zip") {
            Write-Host "Русский перевод не подходит к Elden Vins $ver или не скачался: часть текстов Vins будет на английском." -ForegroundColor Yellow
            $mods = @($mods | Where-Object { $_ -ne 'evn' })
        }
    }
    Install-Me3

    # The folder is rebuilt from scratch: switched-off mods disappear, kept ones are repaired. Settings carry over
    $old = @{}
    foreach ($s in $settingsTable) {
        $p = Join-Path $root $s.File
        if (Test-Path -LiteralPath $p) { $old[$s.File] = [IO.File]::ReadAllText($p) }
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    foreach ($id in $mods) {
        Write-Host "Ставлю $($byId[$id].Name)..."
        switch ($id) {
            'vins' {
                Write-Host '  ~6 ГБ, может занять несколько минут'
                Expand-Zip $zip.vins "$root\vins" 'ELDEN VINS NIGHTREIGN/mod' 2
                Add-SkinLinks "$root\vins\parts"
            }
            'evn'  { Expand-Zip $zip.evn "$root\vins" }
            'coop' { Expand-Zip $zip.coop $root 'SeamlessCoop'; Expand-Zip $zip.coopru "$root\SeamlessCoop\locale" }
            default { Expand-Zip $zip[$id] $root }
        }
    }
    foreach ($f in $old.Keys) {
        $p = Join-Path $root $f
        if (Test-Path -LiteralPath $p) { [IO.File]::WriteAllText($p, (Merge-Ini ([IO.File]::ReadAllText($p)) $old[$f])) }
    }

    # One me3 profile and desktop shortcut per way to play. Vins' own profile is not used: it loads nighter.dll
    # (missing from the archive) and NightreignFPSFOV.dll (same job as Unlock The FPS / Adjust The FOV)
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $dlls = @(if ($mods -contains 'fps') { 'UnlockTheFps.dll' }) + @(if ($mods -contains 'fov') { 'AdjustTheFov.dll' })
    $pkg = if ($mods -contains 'vins') { 'vins' }
    $profiles = [ordered]@{}
    if ($mods -contains 'coop') { $profiles['Seamless Co-op'] = @{ Label = 'NIGHTREIGN Seamless Co-op'; Text = New-Profile $false ($dlls + $nrsc) $pkg } }
    # The server redirector cannot run together with Seamless (its readme), hence a separate profile
    if ($mods -contains 'vins') {
        $profiles['Elden Vins online'] = @{ Label = 'NIGHTREIGN Elden Vins онлайн'; Text = New-Profile $true (@('vins/dll/cl_server_redirector.dll') + $dlls) $pkg }
    }
    if (-not $profiles.Count) { $profiles['Nightreign mods'] = @{ Label = 'NIGHTREIGN с модами'; Text = New-Profile $false $dlls $null } }
    Remove-OurShortcuts
    $me3 = Find-Me3
    $icon = Find-GameExe
    $sh = New-Object -ComObject WScript.Shell
    foreach ($name in $profiles.Keys) {
        $p = Join-Path $root "$name.me3"
        [IO.File]::WriteAllText($p, $profiles[$name].Text)
        if (-not $me3) { continue }
        $lnk = $sh.CreateShortcut((Join-Path $desktop "$($profiles[$name].Label).lnk"))
        $lnk.TargetPath = $me3
        $lnk.Arguments = "launch -g nightreign -p `"$p`""
        $lnk.WorkingDirectory = $root
        if ($icon) { $lnk.IconLocation = "$icon,0" }
        $lnk.Save()
    }
    [IO.File]::WriteAllText($marker, "mods = $($mods -join ' ')`r`n")
    Write-Host 'Моды установлены.' -ForegroundColor Green
    if ($me3) { Write-Host "`nИграть: ярлыки $(($profiles.Values | ForEach-Object { "«$($_.Label)»" }) -join ' и ') на рабочем столе. Steam должен быть открыт." }
    Write-Host 'Кнопка «Играть» в Steam запускает игру без модов.'
    Write-Host "Скачанные архивы лежат в ${src}: их можно удалить, тогда починка установки скачает их снова."
}

function Uninstall-Mods {
    Remove-OurShortcuts
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    Write-Host "`nМоды, их настройки и ярлыки удалены. Сохранения в $env:APPDATA\Nightreign и сама игра не тронуты."
    Write-Host "Скачанные архивы остались в $src, Mod Engine 3 удаляется через «Установленные приложения» Windows."
}

# ---------- main ----------

if (Get-Process nightreign -ErrorAction SilentlyContinue) { throw 'Закрой игру и запусти ещё раз.' }
$installed = Test-Path -LiteralPath $marker
if ($Settings -eq 'only') {
    if (-not $installed) { throw 'Моды ещё не установлены, сначала запусти install.bat.' }
    Edit-Settings
    return
}

if (-not $Action) {
    $Action = 'install'
    if ($installed -and -not $Mods) {
        $c = Select-Option "Моды уже установлены в $root" @('Изменить набор модов или починить установку', 'Настроить моды', 'Удалить всё, что поставил пак')
        if ($c -lt 0) { return }
        if ($c -eq 1) { Edit-Settings; return }
        if ($c -eq 2) {
            if ((Select-Option 'Точно удалить все моды и их настройки? Сохранения останутся.' @('Нет', 'Да, удалить всё')) -ne 1) { return }
            $Action = 'remove'
        }
    }
}
if ($Action -eq 'remove') { Uninstall-Mods; return }

if ($Mods) {
    $modSel = @($Mods -split ',' | ForEach-Object Trim)
} else {
    $modSel = if ($installed) { @((Get-IniValue ([IO.File]::ReadAllText($marker)) 'mods') -split ' ' | Where-Object { $_ }) } else { @($catalog | ForEach-Object Id) }
    $modSel = Select-Mods $modSel
    if ($null -eq $modSel) { Write-Host 'Установка отменена.'; return }
    Clear-Host
}

Install-Mods $modSel

if ($Settings -eq 'ask') {
    Write-Host "`nEnter = открыть настройки модов, Esc = пропустить (потом можно через settings.bat)"
    if ((Read-MenuKey) -eq 'Enter') { Edit-Settings; Clear-Host }
}
