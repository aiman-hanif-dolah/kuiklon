# One-command update + reinstall of Kuiklon. No wizard clicks.
# Builds the release, compiles the Inno Setup installer, and silently
# reinstalls it, then relaunches the app.
#
# Run it from anywhere:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\update-install.ps1
# Or double-click install.bat in the repository root.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host '[1/3] Building release...'
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows --release failed.' }

Write-Host '[2/3] Compiling installer...'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make_installer.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }

$installer = Get-ChildItem (Join-Path $repoRoot 'build\installer') -Filter 'kuiklon-setup-*.exe' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $installer) { throw 'No kuiklon-setup-*.exe found in build\installer.' }

Write-Host "[3/3] Installing $($installer.Name) silently..."
# Close the running app so the binaries can be swapped cleanly.
Get-Process kuiklon -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process -FilePath $installer.FullName -ArgumentList '/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait

Start-Process (Join-Path $env:LOCALAPPDATA 'Programs\Kuiklon\kuiklon.exe')
Write-Host 'Kuiklon updated and launched.'