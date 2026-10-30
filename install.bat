<# : batch
@echo off
set "PACK_BAT=%~f0"
set "PACK_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:PACK_BAT))"
pause
exit /b
#>
# Batch/PowerShell polyglot: cmd runs the lines above, PowerShell runs this part. It asks where the pack lives
# (remembered in the registry), brings install.ps1, settings.bat and the mods shipped with the pack up to date
# there from GitHub and runs install.ps1, so a player only needs this file and nothing lands next to it.
# A git checkout next to this file (development) is used as is. $env:NRPACK_DIR sets the folder without asking.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$here = Split-Path -Parent $env:PACK_BAT
$key = 'HKCU:\Software\Nightreign-Modpack'

function Select-PackFolder($start) {
    Add-Type -AssemblyName System.Windows.Forms
    $fb = New-Object Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Куда установить сборку Nightreign? Нужно около 13 ГБ свободного места.'
    $fb.SelectedPath = $start
    $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true }   # or the dialog may open behind the console
    try { if ($fb.ShowDialog($owner) -ne 'OK') { throw 'Папка не выбрана, установка отменена.' } } finally { $owner.Dispose() }
    $p = $fb.SelectedPath
    # An empty folder or an earlier install is used as is; anything else gets a subfolder, so nothing gets mixed in
    if (@(Get-ChildItem -LiteralPath $p -Force).Count -and -not (Test-Path -LiteralPath "$p\install.ps1")) { $p = Join-Path $p 'Nightreign-Modpack' }
    [IO.Directory]::CreateDirectory($p) | Out-Null
    $p
}

function Update-Pack($dir) {
    $zip = Join-Path $env:TEMP 'nightreign-modpack.zip'
    $tmp = Join-Path $env:TEMP 'nightreign-modpack'
    try {
        Write-Host 'Обновляю установщик с GitHub...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest 'https://github.com/takeshilp/Nightreign-Modpack/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing -TimeoutSec 60
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp
        $repo = (Get-ChildItem -LiteralPath $tmp -Directory)[0].FullName
        Copy-Item -LiteralPath "$repo\install.ps1", "$repo\settings.bat", "$repo\README.md", "$repo\LICENSE" -Destination $dir -Force
        foreach ($d in 'mods', 'licenses') {
            [IO.Directory]::CreateDirectory("$dir\$d") | Out-Null
            Copy-Item -Path "$repo\$d\*" -Destination "$dir\$d" -Force
        }
    } catch {
        if (-not (Test-Path -LiteralPath "$dir\install.ps1")) { throw "Не удалось скачать установщик с GitHub: $($_.Exception.Message)" }
        Write-Host "GitHub недоступен ($($_.Exception.Message)), запускаю уже скачанную версию." -ForegroundColor Yellow
    } finally {
        Remove-Item -LiteralPath $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath "$here\.git") { $dir = $here }
elseif ($env:NRPACK_DIR) { $dir = $env:NRPACK_DIR; [IO.Directory]::CreateDirectory($dir) | Out-Null; Update-Pack $dir }
else {
    $dir = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).InstallDir
    if (-not ($dir -and (Test-Path -LiteralPath "$dir\install.ps1"))) { $dir = $null }
    if (-not $dir -and (Test-Path -LiteralPath "$here\install.ps1")) { $dir = $here }   # set up next to install.bat by an older version
    if ($dir) {
        Write-Host "Папка сборки: $dir" -ForegroundColor Cyan
        Write-Host 'Enter = продолжить, Пробел = выбрать другую папку' -ForegroundColor DarkGray
        if ([Console]::ReadKey($true).Key -eq 'Spacebar') { $dir = $null }
    }
    if (-not $dir) { $dir = Select-PackFolder $here }
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -LiteralPath $key -Name InstallDir -Value $dir
    Update-Pack $dir
}
$argv = @(-split "$env:PACK_ARGS" | Where-Object { $_ })
& (Join-Path $dir 'install.ps1') @argv
