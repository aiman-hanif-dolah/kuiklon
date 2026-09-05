; Inno Setup script for Kuiklon.
; Compiled by tools\make_installer.ps1, which replaces @APP_VERSION@ with the
; version declared in pubspec.yaml (single source of truth for versions).
; Installs per-user (no admin required) into %LOCALAPPDATA%\Programs\Kuiklon.
; NOTE: keep every entry on a single line — Inno does not merge indented
; continuation lines in section entries, and parameters get silently dropped.

[Setup]
AppId={{B4E8C7D1-2F5A-4E9B-8C3D-6A1F0E9D7C42}
AppName=Kuiklon
AppVersion=@APP_VERSION@
AppVerName=Kuiklon @APP_VERSION@
AppPublisher=Kuiklon
DefaultDirName={localappdata}\Programs\Kuiklon
DefaultGroupName=Kuiklon
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=kuiklon-setup-@APP_VERSION@
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\kuiklon.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"
Name: "autostart"; Description: "Start Kuiklon when Windows starts"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Kuiklon"; Filename: "{app}\kuiklon.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Kuiklon"; Filename: "{app}\kuiklon.exe"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userstartup}\Kuiklon"; Filename: "{app}\kuiklon.exe"; WorkingDir: "{app}"; Tasks: autostart

[Run]
Filename: "{app}\kuiklon.exe"; Description: "Launch Kuiklon"; Flags: nowait postinstall skipifsilent