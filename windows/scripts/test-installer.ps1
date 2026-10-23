# This file guarantees clean install, reinstall, Start shortcut activation and scoped uninstall on an isolated machine.
[CmdletBinding()]
param([string]$Installer = 'dist/windows/kbsd-v1.0.0-windows-x64-setup.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$uninstallKey = 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/com.ackkerman.kbsd.windows_is1'
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'kbsd.lnk'
$runKey = 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Run'

function Get-LoginCommand {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
    try { if ($key) { $key.GetValue('kbsd') } }
    finally { if ($key) { $key.Dispose() } }
}

$originalRun = Get-LoginCommand
# Never replace a user's existing installation, shortcut or login item during verification.
if ((Test-Path -LiteralPath $uninstallKey) -or (Test-Path -LiteralPath $shortcut) -or $originalRun) {
    throw 'Installer verification requires no existing kbsd installation, Start shortcut or login registration.'
}
$work = [IO.Path]::GetFullPath((Join-Path $repo ('.local/installer-check-' + [Guid]::NewGuid().ToString('N'))))
$installed = Join-Path $work 'installed'
New-Item -ItemType Directory -Force $work | Out-Null
$preferences = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'kbsd'
New-Item -ItemType Directory -Force $preferences | Out-Null
$sentinel = Join-Path $preferences ('installer-check-' + [Guid]::NewGuid().ToString('N'))
'Keep user preferences' | Set-Content -LiteralPath $sentinel -Encoding UTF8
$app = $null
$ownsRunFixture = $false

function Assert-Installer([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Setup {
    $process = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/SP-', '/NORESTART', ('/DIR="{0}"' -f $installed)) -Wait -PassThru -WindowStyle Hidden
    Assert-Installer ($process.ExitCode -eq 0) "Installer exited with $($process.ExitCode)."
}

function Invoke-Uninstall {
    $uninstaller = Join-Path $installed 'unins000.exe'
    if (Test-Path -LiteralPath $uninstaller) {
        $process = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -Wait -PassThru -WindowStyle Hidden
        Assert-Installer ($process.ExitCode -eq 0) "Uninstaller exited with $($process.ExitCode)."
    }
}

try {
    Invoke-Setup
    Assert-Installer (Test-Path -LiteralPath $uninstallKey) 'Installed Apps registration is missing.'
    Assert-Installer ((Get-ItemPropertyValue -LiteralPath $uninstallKey -Name DisplayName) -eq 'kbsd') 'Installed Apps identity differs.'
    Assert-Installer (Test-Path -LiteralPath $shortcut) 'Start Menu shortcut is missing.'
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $executable = Join-Path $installed 'kbsd.exe'
    Assert-Installer ($link.TargetPath -eq $executable -and $link.WorkingDirectory -eq $installed) 'Start shortcut does not target the installed app.'
    Assert-Installer (-not (Get-LoginCommand)) 'Installation unexpectedly enabled launch at login.'
    $recordings = Get-ChildItem -LiteralPath (Join-Path $installed 'Sounds') -Recurse -File -Filter '*.wav'
    Assert-Installer ($recordings.Count -eq 182) 'Installer did not retain all 182 recordings.'
    foreach ($recording in $recordings) {
        $relative = [IO.Path]::GetRelativePath((Join-Path $installed 'Sounds'), $recording.FullName)
        $source = Join-Path $repo "public/assets/sounds/preview/$relative"
        Assert-Installer ((Get-FileHash -LiteralPath $recording.FullName).Hash -eq (Get-FileHash -LiteralPath $source).Hash) "Recording changed during installation: $relative"
    }
    $report = Join-Path $work 'diagnostic.json'
    $diagnostic = Start-Process -FilePath $executable -ArgumentList @('--diagnose', '--report', ('"{0}"' -f $report)) -Wait -PassThru -WindowStyle Hidden
    Assert-Installer ($diagnostic.ExitCode -eq 0 -and (Get-Content -LiteralPath $report -Encoding UTF8 | ConvertFrom-Json).verified -eq 182) 'Installed audio diagnostic failed.'
    $app = Start-Process -FilePath $executable -ArgumentList '--background' -PassThru -WindowStyle Hidden
    Assert-Installer ($app.WaitForInputIdle(15000)) 'Background tray did not become ready.'
    # The actual shortcut, rather than a direct EXE call, must activate the existing tray process.
    Start-Process -FilePath $shortcut
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 100
        $app.Refresh()
    } until ($app.MainWindowHandle -ne 0 -or [DateTime]::UtcNow -gt $deadline)
    Assert-Installer ($app.MainWindowHandle -ne 0 -and $app.MainWindowTitle -eq 'kbsd — Settings') 'Start shortcut did not display Settings for the background instance.'
    $instances = @(Get-Process -Name kbsd | Where-Object Path -EQ $executable)
    Assert-Installer ($instances.Count -eq 1) 'Shortcut launch created another tray process.'
    Stop-Process -Id $app.Id
    $app.WaitForExit()
    $app = $null
    Invoke-Setup
    Assert-Installer (Test-Path -LiteralPath $shortcut) 'Reinstall removed the Start shortcut.'
    # Startup cleanup fixtures run only in the disposable CI user profile, never on a developer machine.
    if ($env:GITHUB_ACTIONS -eq 'true') {
        $ownsRunFixture = $true
        $portableCommand = '"C:\portable-kbsd\kbsd.exe" --background'
        if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey | Out-Null }
        Set-ItemProperty -LiteralPath $runKey -Name 'kbsd' -Value $portableCommand
        Invoke-Uninstall
        Assert-Installer ((Get-LoginCommand) -eq $portableCommand) 'Uninstall removed another portable app login item.'
        Remove-ItemProperty -LiteralPath $runKey -Name kbsd
        Invoke-Setup
        Set-ItemProperty -LiteralPath $runKey -Name kbsd -Value ('"{0}" --background' -f $executable)
    }
    Invoke-Uninstall
    Assert-Installer (-not (Test-Path -LiteralPath $shortcut)) 'Uninstall left the Start shortcut.'
    Assert-Installer (-not (Test-Path -LiteralPath $uninstallKey)) 'Uninstall left the Installed Apps entry.'
    Assert-Installer (-not (Test-Path -LiteralPath $executable)) 'Uninstall left the app executable.'
    Assert-Installer (Test-Path -LiteralPath $sentinel) 'Uninstall deleted user preferences.'
    Assert-Installer (-not (Get-LoginCommand)) 'Uninstall left the installed app login item.'
    'PASS: install, 182 original recordings, Start shortcut, background activation, reinstall, uninstall and preserved preferences.'
} finally {
    if ($app -and -not $app.HasExited) { Stop-Process -Id $app.Id; $app.WaitForExit() }
    Invoke-Uninstall
    if ($ownsRunFixture) { Remove-ItemProperty -LiteralPath $runKey -Name kbsd -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $sentinel -ErrorAction SilentlyContinue
}
