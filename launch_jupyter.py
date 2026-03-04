import subprocess
import webbrowser
import time
import socket
import shutil
import ctypes
import multiprocessing


def is_jupyter_running(port=8888):
    """Check if something is already listening on the Jupyter port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0


def show_error(msg):
    """Show a Windows message box (works even with --noconsole)."""
    ctypes.windll.user32.MessageBoxW(0, msg, "Jupyter Launcher", 0x10)


def launch():
    # 1. Already running? Just open the browser tab.
    if is_jupyter_running():
        webbrowser.open("http://localhost:8888")
        return

    # 2. Find the real jupyter binary on PATH (safe when frozen by PyInstaller).
    jupyter_exe = shutil.which("jupyter")
    if not jupyter_exe:
        show_error(
            "Could not find 'jupyter' on PATH.\n"
            "Make sure Jupyter is installed and your environment is active."
        )
        return

    # 3. Launch the server hidden, then open the browser.
    cmd = [
        jupyter_exe, "notebook", "--no-browser",
        "--NotebookApp.token=''",
        "--NotebookApp.password=''",
    ]
    try:
        # CREATE_NO_WINDOW (0x08000000) suppresses the console window
        subprocess.Popen(cmd, creationflags=0x08000000)
        time.sleep(5)
        webbrowser.open("http://localhost:8888")
    except Exception as e:
        show_error(f"Error launching Jupyter:\n{e}")


if __name__ == "__main__":
    # Required by PyInstaller for multiprocessing support
    multiprocessing.freeze_support()
    launch()
