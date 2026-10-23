# This file guarantees an installer built only from a verified, self-contained Windows payload.
[CmdletBinding()]
param([string]$PackageDirectory = 'dist/windows/kbsd', [string]$OutputDirectory = 'dist/windows', [string]$Iscc = 'ISCC.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $repo
try {
    $payload = (Resolve-Path -LiteralPath $PackageDirectory).Path
    foreach ($required in @('kbsd.exe', 'coreclr.dll', 'Sounds', 'Licenses', 'ATTRIBUTION.md', 'README.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $payload $required))) { throw "Installer payload is incomplete: $required" }
    }
    $compiler = Get-Command $Iscc -ErrorAction SilentlyContinue
    if (-not $compiler) {
        foreach ($candidate in @("${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe", "$env:ProgramFiles/Inno Setup 7/ISCC.exe")) {
            if (Test-Path -LiteralPath $candidate) { $Iscc = $candidate; break }
        }
    }
    $version = (Get-Content -LiteralPath package.json -Encoding UTF8 | ConvertFrom-Json).version
    $out = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Force $out | Out-Null
    & $Iscc '/Qp' "/DAppVersion=$version" "/DPayloadDirectory=$payload" "/DInstallerOutputDirectory=$out" 'windows/installer/kbsd.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer compilation failed.' }
    $installer = Join-Path $out "kbsd-v$version-windows-x64-setup.exe"
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $installer).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -Encoding UTF8 (Join-Path $out 'SHA256SUMS-setup.txt')
    Write-Output $installer
} finally { Pop-Location }
