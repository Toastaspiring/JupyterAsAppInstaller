# Jupyter Launcher Installer
# Run this once to install the app, create shortcuts, and register an uninstaller.

$AppName    = "Jupyter Launcher"
$ExeName    = "launch_jupyter.exe"
$InstallDir = "$env:LOCALAPPDATA\JupyterLauncher"
$ExeSrc     = Join-Path $PSScriptRoot $ExeName

# ── 1. Copy the exe ────────────────────────────────────────────────────────────
if (-not (Test-Path $ExeSrc)) {
    Write-Error "Cannot find '$ExeName' next to this script. Make sure both files are in the same folder."
    pause; exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item $ExeSrc "$InstallDir\$ExeName" -Force
Write-Host "Installed to: $InstallDir"

# ── 2. Desktop shortcut ────────────────────────────────────────────────────────
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\$AppName.lnk")
$Shortcut.TargetPath    = "$InstallDir\$ExeName"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description   = "Launch Jupyter Notebook"
$Shortcut.Save()
Write-Host "Desktop shortcut created."

# ── 3. Start Menu shortcut ─────────────────────────────────────────────────────
$StartMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$Shortcut2 = $WshShell.CreateShortcut("$StartMenuDir\$AppName.lnk")
$Shortcut2.TargetPath    = "$InstallDir\$ExeName"
$Shortcut2.WorkingDirectory = $InstallDir
$Shortcut2.Description   = "Launch Jupyter Notebook"
$Shortcut2.Save()
Write-Host "Start Menu shortcut created."

# ── 4. Register uninstaller in Apps & Features ─────────────────────────────────
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\JupyterLauncher"

# Write a small uninstall script next to the exe
$UninstallScript = "$InstallDir\Uninstall.ps1"
@"
Remove-Item '$InstallDir' -Recurse -Force
Remove-Item '$env:USERPROFILE\Desktop\$AppName.lnk' -Force -ErrorAction SilentlyContinue
Remove-Item '$StartMenuDir\$AppName.lnk' -Force -ErrorAction SilentlyContinue
Remove-Item '$UninstallKey' -Force -ErrorAction SilentlyContinue
Write-Host '$AppName has been uninstalled.'
pause
"@ | Set-Content $UninstallScript

$UninstallCmd = "powershell -ExecutionPolicy Bypass -File `"$UninstallScript`""

New-Item -Path $UninstallKey -Force | Out-Null
Set-ItemProperty -Path $UninstallKey -Name "DisplayName"      -Value $AppName
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion"   -Value "1.0"
Set-ItemProperty -Path $UninstallKey -Name "Publisher"        -Value $env:USERNAME
Set-ItemProperty -Path $UninstallKey -Name "InstallLocation"  -Value $InstallDir
Set-ItemProperty -Path $UninstallKey -Name "UninstallString"  -Value $UninstallCmd
Set-ItemProperty -Path $UninstallKey -Name "NoModify"         -Value 1 -Type DWord
Set-ItemProperty -Path $UninstallKey -Name "NoRepair"         -Value 1 -Type DWord
Write-Host "Registered in Apps & Features (Settings > Apps)."

Write-Host ""
Write-Host "Installation complete! You can now launch Jupyter from your Desktop or Start Menu."
pause
