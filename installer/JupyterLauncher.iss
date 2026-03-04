[Setup]
AppName=Jupyter Launcher
AppVersion=1.0
AppPublisher=Louis
DefaultDirName={localappdata}\JupyterLauncher
DefaultGroupName=Jupyter Launcher
UninstallDisplayIcon={app}\launch_jupyter.exe
OutputDir=.
OutputBaseFilename=JupyterLauncher-Setup
SetupIconFile=..\jupyter.ico
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern

[Files]
Source: "..\dist\launch_jupyter.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Jupyter Launcher"; Filename: "{app}\launch_jupyter.exe"
Name: "{group}\Uninstall Jupyter Launcher"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Jupyter Launcher"; Filename: "{app}\launch_jupyter.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\launch_jupyter.exe"; Description: "Launch Jupyter now"; Flags: postinstall nowait skipifsilent
