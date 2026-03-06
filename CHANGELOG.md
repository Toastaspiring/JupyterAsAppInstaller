# Changelog

All notable changes to this project are documented here.

---

## [v1.3.2] - 2026-03-06

### Fixed
- Closing the server now also closes any browser window whose title contains "Jupyter"
- Jupyter is first asked to shut down via its REST API (`/api/shutdown`) before the process is killed, ensuring a graceful shutdown

---

## [v1.3.1] - 2026-03-06

### Fixed
- Port is now centralized in `config.json` (default `8888`) instead of being hardcoded in multiple places
- `stop_server()` no longer uses `taskkill /F` (which would kill all Jupyter processes on the machine) — it now only terminates the process it started, with a 5s grace period before force-kill
- Tkinter dialogs (folder picker, conda env selector) now run on a dedicated UI thread, preventing potential crashes when opened from tray menu callbacks
- Corrupted `config.json` now shows an error dialog instead of silently resetting to defaults

### Added
- **Restart Server** entry in the tray menu
- Tray tooltip now reflects the current state: `Starting…`, `Running`, or `Error`

---

## [v1.3.0] - 2026-03-04

### Added
- GitHub Actions workflow to automatically build the installer on every version tag (`v*.*.*`)
- Code signing via SignPath Foundation — releases are signed when signing is available, unsigned otherwise
- MIT license
- README

### Changed
- Installer (`JupyterLauncher.iss`) significantly expanded: proper app metadata, uninstaller, PATH handling, conditional Jupyter install

---

## [v1.2.0] - 2026-03-04

### Added
- **System tray icon** — the app stays alive in the tray while Jupyter is running
- **Tray menu** with the following options:
  - Open Jupyter
  - Change Notebook Directory (saved to `config.json`)
  - Select Conda Environment (saved to `config.json`)
  - Auto-start with Windows (writes to registry)
  - Stop Server & Exit
- **Smart port polling** — replaces the fixed 5-second sleep; opens the browser as soon as the server is ready (polls every 500ms, 30s timeout)
- If the server is already running when the app launches, it just opens a new browser tab without starting a second tray

---

## [v1.1.0] - 2026-03-04

### Added
- Installer detects if Jupyter is missing and offers to run `pip install notebook` automatically during setup

---

## [v1.0.0] - 2026-03-04

### Added
- Initial release
- `launch_jupyter.py`: launches Jupyter Notebook silently (no console window), skips login prompt, opens browser automatically
- Inno Setup script (`JupyterLauncher.iss`) for a proper Windows installer
- PowerShell fallback installer
