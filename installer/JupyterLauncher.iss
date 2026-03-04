[Setup]
AppName=Jupyter Launcher
AppVersion=1.2
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

[Code]
function IsJupyterInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd.exe', '/C where jupyter', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
            and (ResultCode = 0);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if not IsJupyterInstalled() then
    begin
      if MsgBox('Jupyter Notebook was not found on this machine.' + #13#10#13#10 +
                'Install it now via pip? (Python must be installed)',
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        Exec('cmd.exe', '/C pip install notebook', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
        if ResultCode = 0 then
          MsgBox('Jupyter installed successfully!', mbInformation, MB_OK)
        else
          MsgBox('pip install failed.' + #13#10 +
                 'Please run manually: pip install notebook', mbError, MB_OK);
      end;
    end;
  end;
end;
