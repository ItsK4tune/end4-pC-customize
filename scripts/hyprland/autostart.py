#!/usr/bin/env python3
import fcntl
import json
import os
import subprocess
import sys
import time

runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/qs-{os.getuid()}")
os.makedirs(runtime_dir, exist_ok=True)
LOCK_FILE = os.path.join(runtime_dir, "qs-autostart.lock")
CONFIG_FILE = os.path.join(os.environ["HOME"], ".config", "illogical-impulse", "config.json")
force = "--force" in sys.argv

if not force:
    lock_file = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (BlockingIOError, OSError):
        sys.exit(0)


def dispatch(expression):
    subprocess.run(["hyprctl", "dispatch", expression], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def active_workspace():
    result = subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True)
    try:
        return json.loads(result.stdout)["id"]
    except (ValueError, KeyError):
        return None


if not os.path.exists(CONFIG_FILE):
    sys.exit(0)

with open(CONFIG_FILE) as handle:
    data = json.load(handle)

autostart = data.get("hyprland", {}).get("autostartApps", {})
if not autostart.get("enable", False):
    sys.exit(0)

original = active_workspace()

for app in autostart.get("apps", []):
    command = str(app.get("cmd", "")).strip()
    workspace = int(app.get("workspace", 1) or 1)
    delay = float(app.get("delay", 0) or 0)
    if not command:
        continue

    dispatch(f"hl.dsp.focus({{workspace = {workspace}}})")
    dispatch(f"hl.dsp.exec_cmd({lua_string(os.path.expanduser(command))})")
    time.sleep(max(delay, 0.4))

if original is not None:
    dispatch(f"hl.dsp.focus({{workspace = {original}}})")
