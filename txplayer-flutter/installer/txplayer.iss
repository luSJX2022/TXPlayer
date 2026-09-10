; TXPlayer Flutter 版安装包脚本（Inno Setup 6）
#define MyAppName "TXPlayer"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "TXPlayer"
#define MyAppExeName "txplayer.exe"

[Setup]
AppId={{7C4A9E31-5B2D-4F86-9A1E-3D8B6F0C2A55}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=C:\c\txplayer-flutter\dist
OutputBaseFilename=TXPlayer-Setup-{#MyAppVersion}
SetupIconFile=C:\c\txplayer-flutter\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："

[Files]
Source: "C:\c\txplayer-flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TXPlayer"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 TXPlayer"; Filename: "{uninstallexe}"
Name: "{autodesktop}\TXPlayer"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 TXPlayer"; Flags: nowait postinstall skipifsilent
