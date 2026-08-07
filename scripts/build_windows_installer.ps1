<#
Build the Windows MSIX installer (double-click to install).

Why this script instead of just `dart run msix:create`:
the msix package's *bundled* makeappx.exe can fail on some machines with a
"side-by-side configuration is incorrect" error. So we let msix generate the
manifest + assets (`msix:build`), then pack with the Windows SDK's makeappx.

Usage:
  pwsh scripts/build_windows_installer.ps1
Output:
  build/windows/x64/runner/Release/sleepytime.msix

Note: the .msix must be signed to install on another machine (see
docs/distribution.md). This produces an unsigned package for local testing.
#>
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host '==> Building release + MSIX manifest...' -ForegroundColor Cyan
dart run msix:build

$make = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $make) { throw 'Windows SDK makeappx.exe not found. Install the Windows 10/11 SDK.' }

$rel = 'build\windows\x64\runner\Release'
$out = Join-Path $rel 'sleepytime.msix'
Write-Host "==> Packing with $($make.FullName)" -ForegroundColor Cyan
& $make.FullName pack /o /d $rel /p $out | Select-Object -Last 3

if (Test-Path $out) {
  Write-Host ("==> Built {0} ({1:N1} MB)" -f $out, ((Get-Item $out).Length / 1MB)) -ForegroundColor Green
} else {
  throw 'MSIX was not created.'
}
