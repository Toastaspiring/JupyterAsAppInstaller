# Jupyter Launcher

A lightweight Windows app that starts Jupyter Notebook with one click — no terminal, no login prompt, no hassle.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## Download

Go to [Releases](https://github.com/Toastaspiring/JupyterAsAppInstaller/releases/latest) and download **JupyterLauncher-Setup.exe**.

## What it does

- Launches Jupyter Notebook silently in the background (no console window)
- Opens your browser directly to `http://localhost:8888` — no token or password required
- If Jupyter is already running, just opens a new browser tab instead of starting a second server
- Stays alive in the **system tray** while the server is running

## Features

| Tray menu option | Description |
|---|---|
| Open Jupyter | Opens the browser to localhost:8888 |
| Change Notebook Directory | Pick which folder Jupyter opens in |
| Select Conda Environment | Run Jupyter inside a specific conda env |
| Auto-start with Windows | Start the server automatically on login |
| Stop Server & Exit | Shut down Jupyter and close the tray icon |

Settings (notebook directory, conda env, auto-start) are saved to `config.json` next to the installed executable and persist across sessions.

## Requirements

- Windows 10 / 11
- Python must be installed
- Jupyter Notebook (`pip install notebook`) — the installer will offer to install it automatically if missing

## Install

1. Download `JupyterLauncher-Setup.exe` from [Releases](https://github.com/Toastaspiring/JupyterAsAppInstaller/releases/latest)
2. Run the installer (Next → Next → Finish)
3. A desktop shortcut and Start Menu entry are created
4. If Jupyter is not installed, the setup will offer to install it via pip

## Build from source

```bash
pip install pyinstaller pystray Pillow

python -m PyInstaller --onefile --noconsole --icon=jupyter.ico ^
  --add-data "jupyter.ico;." ^
  --hidden-import pystray._win32 ^
  --hidden-import PIL._imaging ^
  launch_jupyter.py
```

Then compile `installer/JupyterLauncher.iss` with [Inno Setup 6](https://jrsoftware.org/isinfo.php).

## License

MIT — see [LICENSE](LICENSE).
