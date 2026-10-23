; This file guarantees per-user installation, a searchable Start shortcut and scoped uninstall cleanup.
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef PayloadDirectory
  #error PayloadDirectory is required
#endif
#ifndef InstallerOutputDirectory
  #error InstallerOutputDirectory is required
#endif

[Setup]
AppId=com.ackkerman.kbsd.windows
AppName=kbsd
AppVersion={#AppVersion}
AppPublisher=ackkerman
AppPublisherURL=https://kbsd.0xdope.com/
AppSupportURL=https://github.com/ackkerman/kbsd
DefaultDirName={localappdata}\Programs\kbsd
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableProgramGroupPage=yes
DisableWelcomePage=no
WizardStyle=modern
SetupIconFile=..\Kbsd.Desktop\Brand.ico
UninstallDisplayIcon={app}\kbsd.exe
OutputDir={#InstallerOutputDirectory}
OutputBaseFilename=kbsd-v{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
; Keep this name aligned with SingleInstanceActivation. Never replace a running app.
AppMutex=Local\kbsd-desktop
CloseApplications=no
RestartApplications=no
UninstallDisplayName=kbsd

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Files]
Source: "{#PayloadDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\kbsd"; Filename: "{app}\kbsd.exe"; WorkingDir: "{app}"; Comment: "Keyboard sounds and settings"; AppUserModelID: "com.ackkerman.kbsd"

[Run]
Filename: "{app}\kbsd.exe"; Description: "{cm:LaunchProgram,kbsd}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Command: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Preserve another portable installation's startup registration and all user preferences.
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'kbsd', Command) then
      if CompareText(Command, '"' + ExpandConstant('{app}\kbsd.exe') + '" --background') = 0 then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'kbsd');
  end;
end;
