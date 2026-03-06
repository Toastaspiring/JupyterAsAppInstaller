[Setup]
AppName=Jupyter Launcher
AppVersion=1.3
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

// ── Helpers ──────────────────────────────────────────────────────────────────

function IsPythonInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd.exe', '/C python --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
            and (ResultCode = 0);
end;

function IsJupyterInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  // Check via python -m so it works even if jupyter.exe is not yet on PATH
  Result := Exec('cmd.exe', '/C python -m jupyter --version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
            and (ResultCode = 0);
end;

// Write a .ps1 helper to {tmp}, run it via PowerShell, return exit code.
// PowerShell is used so we can refresh PATH from the registry (picks up changes
// made by a Python installer that ran earlier in the same Inno session).
function RunPS1(Script: String): Integer;
var
  ScriptFile: String;
  ResultCode: Integer;
begin
  ScriptFile := ExpandConstant('{tmp}\jl_helper.ps1');
  SaveStringToFile(ScriptFile, Script, False);
  Exec('powershell.exe',
       '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptFile + '"',
       '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
  Result := ResultCode;
end;

// Return the Python Scripts directory (where pip places .exe wrappers).
function GetPythonScriptsPath(): String;
var
  TempFile: String;
  Lines: TArrayOfString;
begin
  Result := '';
  TempFile := ExpandConstant('{tmp}\scripts_dir.txt');
  RunPS1(
    '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +' +
    ' [System.Environment]::GetEnvironmentVariable("Path","User");' + #13#10 +
    '$p = & python -c ''import sysconfig; print(sysconfig.get_path("scripts"))'';' + #13#10 +
    'Set-Content -Path "' + TempFile + '" -Value $p -Encoding ASCII;'
  );
  if LoadStringsFromFile(TempFile, Lines) and (GetArrayLength(Lines) > 0) then
    Result := Trim(Lines[0]);
end;

procedure AddDirToUserPath(Dir: String);
var
  CurrentPath: String;
begin
  if Dir = '' then Exit;
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', CurrentPath) then
    CurrentPath := '';
  if Pos(Lowercase(Dir), Lowercase(CurrentPath)) > 0 then Exit; // already present
  if CurrentPath <> '' then
    CurrentPath := CurrentPath + ';' + Dir
  else
    CurrentPath := Dir;
  RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', CurrentPath);
end;

// ── Main install logic ────────────────────────────────────────────────────────

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  PythonInstallerPath: String;
  ScriptsDir: String;
begin
  if CurStep <> ssPostInstall then Exit;

  // ── Step 1: Python ──────────────────────────────────────────────────────────
  if not IsPythonInstalled() then
  begin
    if MsgBox(
      'Python is not installed on this machine.' + #13#10#13#10 +
      'Jupyter requires Python. Download and install Python 3.12 now?',
      mbConfirmation, MB_YESNO) = IDNO then
      Exit;

    PythonInstallerPath := ExpandConstant('{tmp}\python-installer.exe');

    // Download Python 3.12 (64-bit) via PowerShell
    ResultCode := RunPS1(
      'Invoke-WebRequest' +
      ' -Uri "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"' +
      ' -OutFile "' + PythonInstallerPath + '"' +
      ' -UseBasicParsing'
    );

    if (ResultCode <> 0) or not FileExists(PythonInstallerPath) then
    begin
      MsgBox(
        'Failed to download the Python installer.' + #13#10 +
        'Please install Python from https://www.python.org and re-run this installer.',
        mbError, MB_OK);
      Exit;
    end;

    // Silent per-user install; PrependPath=1 adds Python + Scripts to user PATH
    Exec(PythonInstallerPath,
         '/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_pip=1',
         '', SW_SHOW, ewWaitUntilTerminated, ResultCode);

    if ResultCode <> 0 then
    begin
      MsgBox(
        'Python installation failed.' + #13#10 +
        'Please install Python manually from https://www.python.org',
        mbError, MB_OK);
      Exit;
    end;

    MsgBox('Python 3.12 installed successfully!', mbInformation, MB_OK);
  end;

  // ── Step 2: Jupyter ─────────────────────────────────────────────────────────
  if not IsJupyterInstalled() then
  begin
    if MsgBox(
      'Jupyter Notebook is not installed.' + #13#10#13#10 +
      'Install it now via pip?',
      mbConfirmation, MB_YESNO) = IDNO then
      Exit;

    // Run pip through PowerShell so it refreshes PATH from registry first.
    // This is necessary when Python was just installed in this same session.
    ResultCode := RunPS1(
      '$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +' +
      ' [System.Environment]::GetEnvironmentVariable("Path","User");' + #13#10 +
      'pip install notebook'
    );

    if ResultCode = 0 then
    begin
      // Add the Python Scripts dir to user PATH so jupyter.exe is on PATH
      ScriptsDir := GetPythonScriptsPath();
      if ScriptsDir <> '' then
        AddDirToUserPath(ScriptsDir);
      MsgBox(
        'Jupyter Notebook installed successfully!' + #13#10 +
        'The Python Scripts folder has been added to your PATH.',
        mbInformation, MB_OK);
    end else
      MsgBox(
        'pip install failed.' + #13#10 +
        'Please run manually: pip install notebook',
        mbError, MB_OK);
  end;
end;
