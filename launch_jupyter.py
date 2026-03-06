import subprocess
import webbrowser
import time
import socket
import shutil
import ctypes
import multiprocessing
import sys
import json
import winreg
import threading
import queue
from pathlib import Path

import pystray
from PIL import Image
import tkinter as tk
from tkinter import filedialog, ttk

# ── Paths ──────────────────────────────────────────────────────────────────────
# When frozen by PyInstaller, bundled files are in sys._MEIPASS (temp).
# Config/state must live next to the exe (persistent, writable).
if getattr(sys, 'frozen', False):
    RESOURCE_DIR = Path(sys._MEIPASS)
    CONFIG_DIR   = Path(sys.executable).parent
else:
    RESOURCE_DIR = Path(__file__).parent
    CONFIG_DIR   = Path(__file__).parent

ICON_PATH   = RESOURCE_DIR / "jupyter.ico"
CONFIG_PATH = CONFIG_DIR   / "config.json"

# ── Dialogs (defined early — used by load_config) ──────────────────────────────
def show_error(msg):
    ctypes.windll.user32.MessageBoxW(0, msg, "Jupyter Launcher", 0x10)

def show_info(msg):
    ctypes.windll.user32.MessageBoxW(0, msg, "Jupyter Launcher", 0x40)

# ── Config ─────────────────────────────────────────────────────────────────────
DEFAULT_CONFIG = {
    "notebook_dir": str(Path.home() / "Documents"),
    "conda_env":    None,
    "auto_start":   False,
    "port":         8888,
}

def load_config():
    cfg = DEFAULT_CONFIG.copy()
    if CONFIG_PATH.exists():
        try:
            cfg.update(json.loads(CONFIG_PATH.read_text()))
        except Exception as e:
            show_error(f"Config file is corrupted and was reset to defaults.\n\n({e})")
    return cfg

def save_config(cfg):
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2))

# ── Network ────────────────────────────────────────────────────────────────────
def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def wait_for_port(port, timeout=30):
    """Poll every 500 ms until Jupyter is up — no fixed sleep."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if is_port_open(port):
            return True
        time.sleep(0.5)
    return False

# ── Conda ──────────────────────────────────────────────────────────────────────
def list_conda_envs():
    conda = shutil.which("conda")
    if not conda:
        return []
    try:
        result = subprocess.run(
            [conda, "env", "list", "--json"],
            capture_output=True, text=True, timeout=10
        )
        data = json.loads(result.stdout)
        return [Path(p).name for p in data.get("envs", [])]
    except Exception:
        return []

def get_jupyter_cmd(cfg):
    env = cfg.get("conda_env")
    if env:
        conda = shutil.which("conda")
        if conda:
            return [conda, "run", "-n", env, "jupyter"]
    jupyter = shutil.which("jupyter")
    return [jupyter] if jupyter else None

# ── Server ─────────────────────────────────────────────────────────────────────
_server_proc = None

def start_server(cfg):
    global _server_proc
    cmd = get_jupyter_cmd(cfg)
    if not cmd:
        show_error("Could not find 'jupyter' on PATH.\nMake sure Jupyter is installed.")
        return False
    cmd += [
        "notebook", "--no-browser",
        f"--notebook-dir={cfg['notebook_dir']}",
        f"--port={cfg['port']}",
        "--NotebookApp.token=''",
        "--NotebookApp.password=''",
    ]
    _server_proc = subprocess.Popen(cmd, creationflags=0x08000000)
    return True

def _shutdown_jupyter_api(port):
    """Ask Jupyter to shut down via its REST API (graceful, no auth required)."""
    try:
        from urllib.request import urlopen, Request
        req = Request(f"http://localhost:{port}/api/shutdown", method="POST")
        urlopen(req, timeout=3)
    except Exception:
        pass

def _close_jupyter_browser_windows():
    """Close any top-level browser windows whose title contains 'Jupyter'."""
    WM_CLOSE = 0x0010
    handles = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def _cb(hwnd, _):
        length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        if length > 0:
            buf = ctypes.create_unicode_buffer(length + 1)
            ctypes.windll.user32.GetWindowTextW(hwnd, buf, length + 1)
            if "Jupyter" in buf.value:
                handles.append(hwnd)
        return True

    ctypes.windll.user32.EnumWindows(_cb, None)
    for hwnd in handles:
        ctypes.windll.user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)

def stop_server(port=None):
    global _server_proc
    if port and is_port_open(port):
        _shutdown_jupyter_api(port)
        time.sleep(0.5)  # let Jupyter handle the shutdown event before we kill it
    if _server_proc:
        _server_proc.terminate()
        try:
            _server_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            _server_proc.kill()
        _server_proc = None
    _close_jupyter_browser_windows()

# ── Auto-start ─────────────────────────────────────────────────────────────────
_RUN_KEY  = r"Software\Microsoft\Windows\CurrentVersion\Run"
_RUN_NAME = "JupyterLauncher"

def is_autostart_enabled():
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _RUN_KEY, 0, winreg.KEY_READ)
        winreg.QueryValueEx(key, _RUN_NAME)
        winreg.CloseKey(key)
        return True
    except FileNotFoundError:
        return False

def set_autostart(enabled):
    exe = f'"{sys.executable}"' if getattr(sys, 'frozen', False) else f'pythonw "{__file__}"'
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _RUN_KEY, 0, winreg.KEY_SET_VALUE)
    if enabled:
        winreg.SetValueEx(key, _RUN_NAME, 0, winreg.REG_SZ, exe)
    else:
        try:
            winreg.DeleteValue(key, _RUN_NAME)
        except FileNotFoundError:
            pass
    winreg.CloseKey(key)

# ── Tkinter UI thread ──────────────────────────────────────────────────────────
# All Tkinter windows run on a single dedicated thread to avoid thread-safety issues.
_ui_queue = queue.Queue()

def _ui_worker():
    while True:
        func, result_holder, done_event = _ui_queue.get()
        result_holder[0] = func()
        done_event.set()

threading.Thread(target=_ui_worker, daemon=True).start()

def _run_in_ui(func):
    """Run a Tkinter callable on the dedicated UI thread and return its result."""
    result_holder = [None]
    done_event = threading.Event()
    _ui_queue.put((func, result_holder, done_event))
    done_event.wait()
    return result_holder[0]

def pick_folder(current):
    def _fn():
        root = tk.Tk()
        root.withdraw()
        root.wm_attributes('-topmost', True)
        folder = filedialog.askdirectory(title="Select Notebook Directory", initialdir=current)
        root.destroy()
        return folder or None
    return _run_in_ui(_fn)

def pick_conda_env(envs):
    def _fn():
        selected = [None]
        root = tk.Tk()
        root.title("Select Conda Environment")
        root.resizable(False, False)
        root.wm_attributes('-topmost', True)
        tk.Label(root, text="Select conda environment:", padx=10, pady=8).pack()
        var = tk.StringVar(value=envs[0])
        ttk.Combobox(root, textvariable=var, values=envs, state="readonly", width=32).pack(padx=10)
        def ok():
            selected[0] = var.get()
            root.destroy()
        frame = tk.Frame(root)
        frame.pack(pady=8)
        tk.Button(frame, text="OK",     command=ok,           width=10).pack(side=tk.LEFT, padx=4)
        tk.Button(frame, text="Cancel", command=root.destroy, width=10).pack(side=tk.LEFT, padx=4)
        root.mainloop()
        return selected[0]
    return _run_in_ui(_fn)

# ── Tray ───────────────────────────────────────────────────────────────────────
def build_tray_menu(cfg):

    def open_jupyter(_icon, _item):
        webbrowser.open(f"http://localhost:{cfg['port']}")

    def restart(_icon, _item):
        def _run():
            _icon.title = "Jupyter Launcher — Stopping…"
            stop_server(cfg["port"])
            _icon.title = "Jupyter Launcher — Starting…"
            if not start_server(cfg):
                _icon.title = "Jupyter Launcher — Error"
                return
            if not wait_for_port(cfg["port"], timeout=30):
                show_error("Jupyter did not respond within 30 seconds.")
                stop_server(cfg["port"])
                _icon.title = "Jupyter Launcher — Error"
                return
            _icon.title = "Jupyter Launcher — Running"
            webbrowser.open(f"http://localhost:{cfg['port']}")
        threading.Thread(target=_run, daemon=True).start()

    def change_dir(_icon, _item):
        def _run():
            folder = pick_folder(cfg["notebook_dir"])
            if folder:
                cfg["notebook_dir"] = folder
                save_config(cfg)
                show_info(f"Notebook directory updated:\n{folder}\n\nRestart the server to apply.")
        threading.Thread(target=_run, daemon=True).start()

    def change_env(_icon, _item):
        def _run():
            envs = list_conda_envs()
            if not envs:
                show_info("No conda environments found.")
                return
            env = pick_conda_env(envs)
            if env:
                cfg["conda_env"] = env
                save_config(cfg)
                show_info(f"Conda environment set to: {env}\n\nRestart the server to apply.")
        threading.Thread(target=_run, daemon=True).start()

    def toggle_autostart(_icon, _item):
        enabled = not is_autostart_enabled()
        set_autostart(enabled)
        cfg["auto_start"] = enabled
        save_config(cfg)

    def stop_and_exit(icon, _item):
        stop_server(cfg["port"])
        icon.stop()

    return pystray.Menu(
        pystray.MenuItem("Open Jupyter",              open_jupyter, default=True),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Restart Server",            restart),
        pystray.MenuItem("Change Notebook Directory", change_dir),
        pystray.MenuItem("Select Conda Environment",  change_env),
        pystray.MenuItem(
            "Auto-start with Windows",
            toggle_autostart,
            checked=lambda item: is_autostart_enabled(),
        ),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Stop Server & Exit",        stop_and_exit),
    )

def make_tray_image():
    if ICON_PATH.exists():
        return Image.open(str(ICON_PATH)).convert("RGBA")
    # Fallback: plain orange square
    return Image.new("RGBA", (64, 64), (255, 120, 0, 255))

# ── Main ───────────────────────────────────────────────────────────────────────
def launch():
    cfg = load_config()
    port = cfg["port"]

    if is_port_open(port):
        # Server already up — just open the browser, don't start a second tray
        webbrowser.open(f"http://localhost:{port}")
        return

    icon = pystray.Icon(
        "JupyterLauncher",
        make_tray_image(),
        "Jupyter Launcher — Starting…",
        build_tray_menu(cfg),
    )

    def _start():
        if not start_server(cfg):
            icon.stop()
            return
        if not wait_for_port(port, timeout=30):
            show_error("Jupyter did not respond within 30 seconds.")
            stop_server(port)
            icon.stop()
            return
        icon.title = "Jupyter Launcher — Running"
        webbrowser.open(f"http://localhost:{port}")

    threading.Thread(target=_start, daemon=True).start()
    icon.run()


if __name__ == "__main__":
    multiprocessing.freeze_support()
    launch()
