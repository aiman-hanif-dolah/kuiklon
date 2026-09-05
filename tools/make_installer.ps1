# Builds the distributable Kuiklon Windows installer.
#
# Reads the version from pubspec.yaml (single source of truth), renders
# tools\installer.iss with it, and compiles the installer with Inno Setup
# (ISCC) into build\installer\kuiklon-setup-<version>.exe.
#
# Requires the release build to exist first:
#   flutter build windows --release
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\make_installer.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Get-Content (Join-Path $repoRoot 'pubspec.yaml')
$match = $pubspec | Select-String -Pattern '^version:\s*(.+)$'
if (-not $match) { throw 'Could not read version from pubspec.yaml.' }
$version = $match.Matches[0].Groups[1].Value.Trim()

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 not found. Install it from https://jrsoftware.org/isinfo.php'
}

$outDir = Join-Path $repoRoot 'build\installer'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$template = Get-Content (Join-Path $PSScriptRoot 'installer.iss') -Raw
$iss = Join-Path $outDir 'kuiklon.iss'
($template -replace '@APP_VERSION@', $version) |
    Set-Content -Path $iss -Encoding UTF8

Write-Host "Compiling Kuiklon $version installer..."
& $iscc $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE." }

Write-Host "Installer ready: $(Join-Path $outDir "kuiklon-setup-$version.exe")"