# This file guarantees a self-contained Windows ZIP containing original recordings, attribution and SHA256.
[CmdletBinding()]
param([string]$Dotnet = 'dotnet', [string]$OutputDirectory = 'dist/windows')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $repo
try {
    $out = [IO.Path]::GetFullPath($OutputDirectory)
    $package = Join-Path $out 'kbsd'
    New-Item -ItemType Directory -Force $out | Out-Null
    # A fresh staging directory prevents stale runtime files from entering later packages.
    $stage = Join-Path $out ('stage-' + [Guid]::NewGuid().ToString('N'))
    & $Dotnet publish windows/Kbsd.Desktop -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o $stage --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Self-contained Windows publish failed.' }
    # Self-contained runtimes retain their upstream license and third-party notices.
    $assets = Get-Content -Encoding UTF8 windows/Kbsd.Desktop/obj/project.assets.json | ConvertFrom-Json -AsHashtable
    $runtimeNotices = 0
    $downloads = $assets.project.frameworks.Values | ForEach-Object { $_.downloadDependencies }
    foreach ($dependency in $downloads) {
        if ($dependency.name -notmatch '^Microsoft\.(NETCore|WindowsDesktop)\.App\.Runtime\.win-x64$') { continue }
        $packageId = $dependency.name
        $runtimeVersion = $dependency.version.Trim([char[]]'[] ').Split(',')[0].Trim()
        $destination = Join-Path $stage "Licenses/$packageId"
        New-Item -ItemType Directory -Force $destination | Out-Null
        foreach ($root in $assets.packageFolders.Keys) {
            $runtime = Join-Path $root "$($packageId.ToLowerInvariant())/$runtimeVersion"
            foreach ($notice in (Get-ChildItem -LiteralPath $runtime -File -ErrorAction SilentlyContinue | Where-Object Name -Match '^(LICENSE|THIRD-PARTY-NOTICES)(\..*)?$')) {
                Copy-Item -LiteralPath $notice.FullName -Destination $destination
                $runtimeNotices++
            }
        }
    }
    if ($runtimeNotices -lt 3) { throw 'Expected .NET and Windows Desktop runtime licenses and third-party notices.' }
    Copy-Item -LiteralPath (Join-Path $repo 'ATTRIBUTION.md') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $repo 'windows/README.md') -Destination (Join-Path $stage 'README.md')
    $report = Join-Path $stage 'diagnostic.json'
    $process = Start-Process -FilePath (Join-Path $stage 'kbsd.exe') -ArgumentList @('--diagnose', '--report', ('"{0}"' -f $report)) -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw 'Published recording diagnostic failed.' }
    $result = Get-Content -Encoding UTF8 $report | ConvertFrom-Json
    if ($result.verified -ne 182) { throw 'Published package must render all 182 original recordings.' }
    Remove-Item -LiteralPath $report
    # Resolve and constrain the replacement target before any recursive deletion.
    if (Test-Path -LiteralPath $package) {
        $resolved = (Resolve-Path -LiteralPath $package).Path
        if ($resolved -ne (Join-Path $out 'kbsd') -or (Split-Path $resolved -Parent) -ne $out) { throw 'Unsafe Windows package replacement target.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Move-Item -LiteralPath $stage -Destination $package
    $version = (Get-Content -Encoding UTF8 package.json | ConvertFrom-Json).version
    $zip = Join-Path $out "kbsd-v$version-windows-x64.zip"
    Compress-Archive -LiteralPath $package -DestinationPath $zip -Force
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -Encoding UTF8 (Join-Path $out 'SHA256SUMS.txt')
    Write-Output $zip
} finally { Pop-Location }
