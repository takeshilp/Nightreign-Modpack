<# : batch
@echo off
set "PACK_BAT=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:PACK_BAT))" || goto end
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
:end
pause
exit /b
#>
# Batch/PowerShell polyglot: cmd runs the lines above, PowerShell runs this part first. It brings install.ps1,
# settings.bat and the mods shipped with the pack up to date from GitHub, so a player only needs this file.
# Skipped in a git checkout (development); without internet the copy already here is used.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$dir = Split-Path -Parent $env:PACK_BAT
if (Test-Path -LiteralPath "$dir\.git") { return }
$zip = Join-Path $env:TEMP 'nightreign-modpack.zip'
$tmp = Join-Path $env:TEMP 'nightreign-modpack'
try {
    Write-Host 'Обновляю установщик с GitHub...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://github.com/takeshilp/Nightreign-Modpack/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing -TimeoutSec 60
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp
    $repo = (Get-ChildItem -LiteralPath $tmp -Directory)[0].FullName
    # install.bat itself is left alone: cmd is still reading it
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
