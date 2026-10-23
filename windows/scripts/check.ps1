# This file guarantees Windows formatting, compilation, scenario tests and packaged-audio diagnostics.
[CmdletBinding()]
param([string]$Dotnet = 'dotnet')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $repo
try {
    foreach ($script in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1')) {
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw "Invalid PowerShell syntax: $($script.Name): $parseErrors" }
    }
    foreach ($project in @('Kbsd.Core', 'Kbsd.Desktop', 'Kbsd.Tests')) {
        & $Dotnet restore "windows/$project" --nologo
        if ($LASTEXITCODE -ne 0) { throw "Restore failed: $project" }
        & $Dotnet format "windows/$project" --verify-no-changes --no-restore
        if ($LASTEXITCODE -ne 0) { throw "Formatting failed: $project" }
    }
    # Isolated artifacts keep verification from overwriting a running development app.
    & $Dotnet build windows/Kbsd.Desktop -c Release --artifacts-path .local/windows-check --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    & $Dotnet run --project windows/Kbsd.Tests -c Release --artifacts-path .local/windows-check -- public/assets/sounds/preview
    if ($LASTEXITCODE -ne 0) { throw 'Windows scenarios failed.' }
    $app = Join-Path $repo '.local/windows-check/bin/Kbsd.Desktop/release/kbsd.dll'
    $report = Join-Path $repo '.local/windows-check/bin/Kbsd.Desktop/release/diagnostic.json'
    & $Dotnet exec $app --diagnose --report $report
    if ($LASTEXITCODE -ne 0) { throw 'Bundled audio diagnostic failed.' }
    $result = Get-Content -Encoding UTF8 $report | ConvertFrom-Json
    if ($result.loaded -ne 182 -or $result.verified -ne 182) { throw 'Expected all 182 bundled recordings to render.' }
    $result | ConvertTo-Json -Compress
} finally { Pop-Location }
