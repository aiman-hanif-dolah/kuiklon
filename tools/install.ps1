# Installs the latest Kuiklon release build for the current user:
#   - copies build\windows\x64\runner\Release into %LOCALAPPDATA%\Programs\Kuiklon
#   - creates Start Menu and Desktop shortcuts
#   - registers a per-user Apps & Features uninstall entry (HKCU)
#
# Run from the repository root after building:
#   flutter build windows --release
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\install.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$release = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$dest = Join-Path $env:LOCALAPPDATA 'Programs\Kuiklon'

if (-not (Test-Path (Join-Path $release 'kuiklon.exe'))) {
    throw "Release build not found at $release. Run 'flutter build windows --release' first."
}

# Stop any running instance so the binaries can be replaced safely.
Get-Process kuiklon -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

# Fresh copy: remove any previous install, then copy the full release folder
# (exe, DLLs and data\flutter_assets must stay side by side).
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination $dest -Recurse -Force

$exe = Join-Path $dest 'kuiklon.exe'

# Shortcuts (launch with the install dir as working directory).
$shell = New-Object -ComObject WScript.Shell
$startMenuLnk = $shell.CreateShortcut(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Kuiklon.lnk'))
$startMenuLnk.TargetPath = $exe
$startMenuLnk.WorkingDirectory = $dest
$startMenuLnk.Save()

$desktopLnk = $shell.CreateShortcut(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Kuiklon.lnk'))
$desktopLnk.TargetPath = $exe
$desktopLnk.WorkingDirectory = $dest
$desktopLnk.Save()

# Uninstall script (kept inside the install folder).
$uninstallCmd = Join-Path $dest 'uninstall.cmd'
@'
@echo off
taskkill /IM kuiklon.exe /F >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kuiklon" /f >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Kuiklon.lnk" >nul 2>&1
del "%USERPROFILE%\Desktop\Kuiklon.lnk" >nul 2>&1
rd /s /q "%LOCALAPPDATA%\Programs\Kuiklon"
echo Kuiklon uninstalled.
'@ | Set-Content -Path $uninstallCmd -Encoding ASCII

# Register in Apps & Features so it can be uninstalled like any app.
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Kuiklon'
New-Item -Path $key -Force | Out-Null
$version = (Get-Item $exe).VersionInfo.ProductVersion
Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'Kuiklon'
Set-ItemProperty -Path $key -Name 'DisplayVersion' -Value $version
Set-ItemProperty -Path $key -Name 'DisplayIcon' -Value $exe
Set-ItemProperty -Path $key -Name 'Publisher' -Value 'Kuiklon'
Set-ItemProperty -Path $key -Name 'UninstallString' -Value "cmd /c `"$uninstallCmd`""
Set-ItemProperty -Path $key -Name 'NoModify' -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name 'NoRepair' -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name 'InstallLocation' -Value $dest

Write-Host "Kuiklon $version installed at $dest"
Write-Host "Shortcuts: Start Menu + Desktop. Uninstall via Apps & Features or uninstall.cmd."