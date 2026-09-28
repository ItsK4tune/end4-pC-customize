#!/usr/bin/env python3
import json, subprocess, time, os, sys, fcntl

runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/qs-{os.getuid()}")
os.makedirs(runtime_dir, exist_ok=True)
lockfile_path = os.path.join(runtime_dir, "qs-autostart.lock")
lock_file = open(lockfile_path, "w")
try:
    fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
except (BlockingIOError, OSError):
    sys.exit(0)

with open(f"{os.environ['HOME']}/.config/illogical-impulse/config.json") as f:
    data = json.load(f)

autostart = data.get('hyprland', {}).get('autostartApps', {})
if not autostart.get('enable', False):
    exit(0)

for app in autostart.get('apps', []):
    cmd = app.get('cmd', '').strip()
    workspace = app.get('workspace', 1)
    delay = app.get('delay', 0)
    if not cmd:
        continue

    subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{workspace = {workspace}}})'])

    expanded_cmd = os.path.expanduser(cmd)
    subprocess.Popen(
        ['hyprctl', 'dispatch', f'hl.dsp.exec_cmd("{expanded_cmd}")'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )

    time.sleep(delay)