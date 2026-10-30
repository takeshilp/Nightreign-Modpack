# ELDEN RING NIGHTREIGN mod pack installer. install.bat: pick mods, install / change / remove, settings.
# settings.bat: settings only. -Mods, -Action, -Settings skip the menus (used by tests\test-modpack.ps1).
param([string[]]$Mods, [ValidateSet('ask', 'only', 'skip')][string]$Settings = 'ask', [ValidateSet('install', 'remove')][string]$Action)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = Join-Path $PSScriptRoot 'mods'          # mod archives: shipped, downloaded or picked up from Downloads
$root = Join-Path $PSScriptRoot 'installed'    # everything the pack installs; each install rebuilds it from scratch
$marker = Join-Path $root 'modpack.txt'        # which mods are installed
$backup = Join-Path $PSScriptRoot 'settings-backup'   # settings ini copies while installed\ is rebuilt
$nrsc = 'SeamlessCoop/nrsc.dll'
# Test seams: $global:TestDesktop and $global:TestDownloads replace the real folders
$desktop = if ($global:TestDesktop) { $global:TestDesktop } else { [Environment]::GetFolderPath('Desktop') }

# Where each archive comes from. File + Drive + Sha256 = the pack owner's upload to Google Drive, pinned: it is taken
# first, so an update on Drive reaches everyone. Otherwise archives in mods\ or Downloads are recognised by what is
# inside (Has = entry name, -like; Text = a string that entry must contain), since Nexus names browser downloads its
# own way, and the newest match wins; without Has only the exact File counts. GitHub = owner/repo whose latest
# release has the Asset; Nexus = page the player downloads it from by hand.
# No source at all: shipped in this repository's mods\ (MIT-licensed mods)
$sources = @{
    vins   = @{ Has = 'ELDEN VINS NIGHTREIGN/mod/regulation.bin'; File = 'ELDEN VINS NIGHTREIGN-287-1-5-2-1769916199.zip'
                Drive = '1YiEEjlp4MALZNu2AI7Vr5QBgkX6qhc-I'; Sha256 = '945073D5645BABB68BED8CD514356C05787C19378D9FD2A6C2997706BAEBEF60'
                Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/287?tab=files'; Title = 'ELDEN VINS NIGHTREIGN' }
    # Built by tools\merge_evn_ru.py from one Vins zip, whose size is VinsSize: it fits no other Vins version
    evn    = @{ File = 'EVN Russian for ELDEN VINS 1-5-2.zip'; VinsSize = 6298366949
                Drive = '1deIupoipWD3NAwmBIRyUL7GN_1V5o9Pr'; Sha256 = '8CAB8AE94846B87FB5B7D97D5E6D66ACD5AC54B1CD1B533B8A7EBEE0BD92D8E1' }
    coop   = @{ Has = 'SeamlessCoop/nrsc.dll'; File = 'Seamless Co-op (Nightreign)-4199.zip'
                Drive = '19prfPdo4dWrALVkMfX4j4j6vwS2J4ie2'; Sha256 = 'B5D3CBD3CEC5BA9D7C9FAF7C4E51C56A70E21120732C3F3B15E59DFBBD35ACE8'
                Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/3?tab=files'; Title = 'Seamless Co-op' }
    # YUINEXUS: message keys only the Nightreign Seamless has
    coopru = @{ Has = 'russian.json'; Text = 'YUINEXUS'; File = 'Russian Translation of Seamless Co-op (Nightreign)-4319.zip'
                Drive = '17iZ4SYHAotgyqD5jCz--FtDNI4wOD50U'; Sha256 = 'C2AED7BF2EAFF35F5F1B52ED82C9AC92488B63D46628C1B4E9ED1F8790F708D0'
                Nexus = 'https://www.nexusmods.com/eldenringnightreign/mods/775?tab=files'
                Title = 'Russian Translation of Seamless Co-op' }
    fps    = @{ Has = 'UnlockTheFps.dll' }
    fov    = @{ Has = 'AdjustTheFov.dll' }
    mgr    = @{ Has = 'Me3_Manager_*/Me3_Manager.exe'; GitHub = '2Pz/me3-manager'; Asset = 'Me3_Manager_*_Windows.zip' }
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
        'value|num|Угол обзора (FOV)|в игре по умолчанию 48, больше = шире'
    ) }
    @{ Mod = 'Elden Vins: онлайн-сервер'; File = 'vins\dll\cl_server_redirector.ini'; Items = @(
        'CL_SERVER_URL|text|Адрес сервера'
        'CL_CUSTOM_SHARD_NAME|opt|Своя комната на сервере|подбор только с теми, у кого то же имя, до 16 символов'
        'CL_USE_ALT_SAVE|tf|Отдельный сейв NR0000.CL_SAVE|бережёт основной сейв, лучше не выключать'
    ) }
)

# ME3 Manager installs me3 portable into LOCALAPPDATA. The official installer lets the player pick the folder and
# records it in the registry; it also adds me3 to PATH, which this already running process does not see
function Find-Me3 {
    $dirs = "$env:LOCALAPPDATA\garyttierney\me3", (Get-ItemProperty 'HKCU:\Software\garyttierney\me3' -ErrorAction SilentlyContinue).Install_Dir
    foreach ($d in $dirs) { if ($d -and (Test-Path -LiteralPath "$d\bin\me3.exe")) { return "$d\bin\me3.exe" } }
    (Get-Command me3.exe -ErrorAction SilentlyContinue).Source
}

# Test seam: $global:TestGameDir replaces the game folder
function Find-GameExe {
    if ($global:TestGameDir) { return "$global:TestGameDir\nightreign.exe" }
    $steam =(Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
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

# Mod checklist; returns the chosen ids that can be installed (blocked ones left out), or $null when cancelled
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
                if ($sel -eq $rows.Count - 1) { if ($key -eq 'Enter') { return , @($mods | Where-Object { -not (Get-Blocker $byId[$_] $mods) }) } }
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

# The zip has an entry matching the name (-like) whose text contains $text if given; an unreadable zip has none
function Test-ZipEntry($path, $name, $text) {
    try { $z = [IO.Compression.ZipFile]::OpenRead($path) } catch { return $false }
    try {
        foreach ($e in $z.Entries) {
            if (($e.FullName -replace '\\', '/') -notlike $name) { continue }
            if (-not $text) { return $true }
            $r = New-Object IO.StreamReader($e.Open())
            try { if ($r.ReadToEnd().Contains($text)) { return $true } } finally { $r.Dispose() }
        }
        $false
    } finally { $z.Dispose() }
}

# Newest finished archive of this source in the folder (Firefox keeps an empty placeholder next to a .part while
# downloading). Opening a zip reads only its directory, so even the 6 GB one is checked at once
function Find-Archive($dir, $key) {
    $s = $sources[$key]
    $files = Get-ChildItem -LiteralPath $dir -Filter $(if ($s.Has) { '*.zip' } else { $s.File }) -File -ErrorAction SilentlyContinue
    foreach ($f in $files | Sort-Object LastWriteTime -Descending) {
        if ($f.Length -eq 0 -or (Test-Path -LiteralPath "$($f.FullName).part")) { continue }
        if (-not $s.Has -or (Test-ZipEntry $f.FullName $s.Has $s.Text)) { return $f.FullName }
    }
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
function Save-GitHub($repo, $asset, $dir) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $a = @((Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -TimeoutSec 20).assets | Where-Object { $_.name -like $asset })[0]
    if (-not $a) { throw "В последнем релизе $repo на GitHub нет файла $asset." }
    $dest = Join-Path $dir $a.name
    Save-Url $a.browser_download_url $dest ("$($a.digest)" -replace '^sha256:', '')
    $dest
}

# Archive already in mods\, or in Downloads (linked into mods\), recognised by its contents; $null if none
function Get-LocalArchive($key) {
    $have = Find-Archive $src $key
    if ($have) { return $have }
    $dl = Find-Archive (Get-DownloadsDir) $key
    if (-not $dl) { return }
    $dest = Join-Path $src (Split-Path -Leaf $dl)
    try { New-Item -ItemType HardLink -Path $dest -Value $dl | Out-Null } catch { Copy-Item -LiteralPath $dl $dest }
    $dest
}

# Path of an archive in mods\, downloaded or taken from Downloads if needed; $null when it has to come from
# Nexus by hand, or (no Nexus page) when it cannot be had at all. The pinned Drive file goes first: an older copy
# already here is used only when Drive fails
function Get-Archive($key) {
    $s = $sources[$key]
    if ($s.File -and (Test-Path -LiteralPath (Join-Path $src $s.File))) { return Join-Path $src $s.File }
    if ($s.Drive) {
        Write-Host "Качаю $($s.File) с Google Drive..."
        try { Save-Drive $s.Drive (Join-Path $src $s.File) $s.Sha256; return Join-Path $src $s.File }
        catch { Write-Host "Google Drive: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    $have = Get-LocalArchive $key
    if ($have) { return $have }
    if ($s.GitHub) { Write-Host "Качаю $($s.Asset) с GitHub..."; return Save-GitHub $s.GitHub $s.Asset $src }
    if (-not $s.Nexus -and -not $s.ContainsKey('Drive')) { throw "Нет архива с $($s.Has) в папке $src" }   # shipped one
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
    while (@($keys | Where-Object { -not (Find-Archive $src $_) -and -not (Find-Archive $dl $_) }).Count) {
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
    if ($manual) { Wait-Nexus $manual; foreach ($k in $manual) { $zip[$k] = Get-LocalArchive $k } }
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
    if (-not (Test-Path -LiteralPath $parts)) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $parts -Recurse -File -Filter '*.partsbnd.dcx')) {
        if ($f.Name -like '*_l.partsbnd.dcx') { continue }
        $dst = Join-Path $f.DirectoryName ($f.Name -replace '\.partsbnd\.dcx$', '_l.partsbnd.dcx')
        try { New-Item -ItemType HardLink -Path $dst -Value $f.FullName | Out-Null }
        catch { Copy-Item -LiteralPath $f.FullName -Destination $dst }
    }
}

# me3 goes where ME3 Manager puts it, from the same portable release zip: no installer window asking for a folder
function Install-Me3 {
    if (Find-Me3) { return }
    Write-Host 'Ставлю Mod Engine 3 (me3)...'
    $zip = Save-GitHub 'garyttierney/me3' 'me3-windows-amd64.zip' $env:TEMP
    Expand-Zip $zip "$env:LOCALAPPDATA\garyttierney\me3" 'bin'
    Remove-Item -LiteralPath $zip
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

# Unlock The FPS and Adjust The FOV read config.ini from "mods\<dll name>" relative to the game's working folder,
# which me3 sets to the game folder. Junctions there point at their folders in installed\, so the settings stay in
# one place (and the mods' log.txt lands next to them). Only junctions are touched, never a real folder
$cwdMods = @{ fps = 'UnlockTheFps'; fov = 'AdjustTheFov' }
function Update-ModLinks($mods) {
    $exe = Find-GameExe
    if (-not $exe) {
        if ($mods | Where-Object { $cwdMods[$_] }) { Write-Host 'Не нашёл папку игры: настройки Unlock The FPS и Adjust The FOV не применятся.' -ForegroundColor Yellow }
        return
    }
    $dir = Join-Path (Split-Path -Parent $exe) 'mods'
    foreach ($id in $cwdMods.Keys) {
        $link = Join-Path $dir $cwdMods[$id]
        $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        if ($item -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Write-Host "В $dir есть своя папка $($cwdMods[$id]): мод возьмёт настройки из неё, а не из settings.bat." -ForegroundColor Yellow
            continue
        }
        # Not fatal: a game on exFAT (no junctions) or a write-protected game folder only costs these settings
        try {
            if ($item) { [IO.Directory]::Delete($link) }   # removes the junction only, not the folder it points at
            if ($mods -contains $id) {
                [IO.Directory]::CreateDirectory($dir) | Out-Null
                New-Item -ItemType Junction -Path $link -Value (Join-Path $root $cwdMods[$id]) | Out-Null
            }
        } catch {
            Write-Host "Не удалось связать $link с настройками ($($_.Exception.Message)): $($cwdMods[$id]) будет со стандартными." -ForegroundColor Yellow
        }
    }
    if ((Test-Path -LiteralPath $dir -PathType Container) -and -not (Get-ChildItem -LiteralPath $dir -Force)) { Remove-Item -LiteralPath $dir }
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
    # The patch carries whole Vins text files: on another Vins version it would replace newer Vins texts
    if ($mods -contains 'evn' -and (-not $zip.evn -or (Get-Item -LiteralPath $zip.vins).Length -ne $sources.evn.VinsSize)) {
        Write-Host 'Русский перевод не подходит к этой версии Elden Vins или не скачался: часть текстов Vins будет на английском.' -ForegroundColor Yellow
        $mods = @($mods | Where-Object { $_ -ne 'evn' })
    }
    Install-Me3

    # The folder is rebuilt from scratch: switched-off mods disappear, kept ones are repaired. Settings carry over
    # through copies on disk, which go only once the new folder is complete: a rebuild that stops half-way (full
    # disk, locked file) loses nothing, and the next run picks the copies up. A copy that is already there is left
    # alone: it comes from such a run, while the file in installed\ may already be a fresh default
    foreach ($s in $settingsTable) {
        $p = Join-Path $root $s.File
        $b = Join-Path $backup $s.File
        if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $b)) | Out-Null
            Copy-Item -LiteralPath $p $b
        }
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
    foreach ($s in $settingsTable) {
        $p = Join-Path $root $s.File
        $b = Join-Path $backup $s.File
        if ((Test-Path -LiteralPath $p) -and (Test-Path -LiteralPath $b)) { [IO.File]::WriteAllText($p, (Merge-Ini ([IO.File]::ReadAllText($p)) ([IO.File]::ReadAllText($b)))) }
    }
    Update-ModLinks $mods

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
    Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Моды установлены.' -ForegroundColor Green
    if ($me3) { Write-Host "`nИграть: ярлыки $(($profiles.Values | ForEach-Object { "«$($_.Label)»" }) -join ' и ') на рабочем столе. Steam должен быть открыт." }
    Write-Host 'Кнопка «Играть» в Steam запускает игру без модов.'
    Write-Host "Скачанные архивы лежат в ${src}: их можно удалить, тогда починка установки скачает их снова."
}

function Uninstall-Mods {
    Remove-OurShortcuts
    Update-ModLinks @()
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    Write-Host "`nМоды, их настройки и ярлыки удалены. Сохранения в $env:APPDATA\Nightreign и сама игра не тронуты."
    Write-Host "Скачанные архивы остались в $src, Mod Engine 3 удаляется через «Установленные приложения» Windows."
}

# ---------- main ----------

# ME3 Manager runs from installed\, and a rebuild cannot delete its files while it is open
if (Get-Process nightreign, Me3_Manager -ErrorAction SilentlyContinue) { throw 'Закрой игру и Mod Engine 3 Manager и запусти ещё раз.' }
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
    if (-not $modSel) { Write-Host 'Установка отменена.'; return }   # cancelled, or nothing ticked
    Clear-Host
}

Install-Mods $modSel

if ($Settings -eq 'ask') {
    Write-Host "`nEnter = открыть настройки модов, Esc = пропустить (потом: settings.bat в папке $PSScriptRoot)"
    if ((Read-MenuKey) -eq 'Enter') { Edit-Settings; Clear-Host }
}
