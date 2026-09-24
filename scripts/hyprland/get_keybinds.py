#!/usr/bin/env python3
import argparse
import re
import os
import json
from typing import Dict, List, Optional

HIDE_MARKERS = ["[hidden]", "# [hidden]"]

parser = argparse.ArgumentParser(description='Hyprland Lua keybind reader')
parser.add_argument('--path', type=str, default="$HOME/.config/hypr/hyprland/keybinds.lua")
args = parser.parse_args()

content_lines = []
reading_line = 0


class KeyBinding(dict):
    def __init__(self, mods, key, dispatcher, params, comment):
        self["mods"]       = mods
        self["key"]        = key
        self["dispatcher"] = dispatcher
        self["params"]     = params
        self["comment"]    = comment


class Section(dict):
    def __init__(self, children, keybinds, name):
        self["children"] = children
        self["keybinds"] = keybinds
        self["name"]     = name


def read_content(path: str) -> str:
    expanded = os.path.expanduser(os.path.expandvars(path))
    if not os.access(expanded, os.R_OK):
        return "error"
    with open(expanded, "r") as f:
        return f.read()


def parse_key_string(key_str: str):
    """Parse 'SUPER + SHIFT + Q' into (['SUPER', 'SHIFT'], 'Q')"""
    known_mods = {"SUPER", "SHIFT", "CTRL", "ALT", "META"}
    parts = [p.strip() for p in key_str.split("+")]
    mods, key = [], ""
    for p in parts:
        if p.upper() in known_mods:
            mods.append(p)
        else:
            key = p
    if not key and mods:
        key = mods.pop()
    # Format mouse buttons cleanly
    if key.startswith("mouse:"):
        mouse_map = {
            "mouse:272": "Left Click",
            "mouse:273": "Right Click",
            "mouse:274": "Middle Click",
            "mouse:275": "Side Button",
        }
        key = mouse_map.get(key, key)
    return mods, key

def autogenerate_comment(dispatcher: str, params: str = "") -> str:
    d = dispatcher.lower()
    if "exec_cmd" in d or "exec" in d:
        p = params.strip(' "\'')
        if any(x in params for x in ["qsIsAlive", "qsIpcCall", "qsScripts", "hyprScripts", "grimhyprctl", "mediaNextCommand", ".."]):
            return ""
        if p == "terminal":
            return "App: Terminal"
        if "wpctl set-volume" in p:
            if "2%+" in p: return "Audio: Volume up"
            if "2%-" in p: return "Audio: Volume down"
            return "Audio: Adjust volume"
        if "wpctl set-mute" in p:
            if "DEFAULT_AUDIO_SINK" in p or "DEFAULT_SINK" in p:
                return "Audio: Toggle mute"
            if "DEFAULT_SOURCE" in p:
                return "Audio: Toggle microphone"
        if "playerctl" in p:
            if "play-pause" in p: return "Media: Play / Pause"
            if "previous" in p: return "Media: Previous track"
            if "next" in p: return "Media: Next track"
        return ""

def is_hidden(line: str) -> bool:
    for marker in HIDE_MARKERS:
        if marker in line:
            return True
    return False


def parse_lua_bind(line: str, override_comment: str = "") -> Optional[KeyBinding]:
    """
    Handles:
      hl.bind("SUPER + Q", hl.dsp.window.close(), {description = "Close"})
      hl.bind("SUPER + Q", function() ... end, {description = "..."})
    """
    if is_hidden(line):
        return None

    m = re.match(r'\s*hl\.bind\s*\(\s*"([^"]+)"\s*,\s*(.*)', line, re.DOTALL)
    if not m:
        return None

    key_str = m.group(1).strip()
    rest    = m.group(2)

    # Extract description from options table
    desc_match = re.search(r'description\s*=\s*"([^"]+)"', rest)
    comment    = override_comment or (desc_match.group(1) if desc_match else "")

    if is_hidden(rest) or is_hidden(comment):
        return None

    # Extract dispatcher name
    disp_match = re.match(r'(hl\.dsp\.[a-zA-Z_.]+)', rest)
    if disp_match:
        dispatcher = disp_match.group(1)
        # Extract params inside dispatcher call parens
        params_match = re.search(r'hl\.dsp\.[a-zA-Z_.]+\(([^)]*)\)', rest)
        params = params_match.group(1).strip() if params_match else ""
    elif rest.strip().startswith("function"):
        dispatcher = "function"
        params     = ""
    else:
        dispatcher = rest.split(",")[0].strip()
        params     = ""

    if not comment:
        comment = autogenerate_comment(dispatcher, params)

    if not comment:
        return None  # Skip binds with no useful description

    mods, key = parse_key_string(key_str)
    return KeyBinding(mods, key, dispatcher, params, comment)


def get_binds_recursive(current_content: Section, scope: int) -> Section:
    global content_lines, reading_line

    while reading_line < len(content_lines):
        line = content_lines[reading_line]

        # ── Section headings ──────────────────────────────────────────
        # --##! Title  (scope 2)
        # --###! Title (scope 3)
        heading_match = re.match(r'^(-+#+)!\s*(.*)', line)
        if heading_match:
            heading_scope = heading_match.group(1).count("#")
            section_name  = heading_match.group(2).strip()
            if heading_scope <= scope:
                reading_line -= 1
                return current_content
            reading_line += 1
            current_content["children"].append(
                get_binds_recursive(Section([], [], section_name), heading_scope)
            )
            reading_line += 1
            continue

        # ── Special comment bind: --#/# hl.bind(...) ─────────────────
        # Used for loop-generated binds that need a custom label
        # e.g.: --#/# bind = SUPER + ←/↑/→/↓,, -- Focus in direction
        comment_bind_match = re.match(r'^--#/#\s*(.*)', line)
        if comment_bind_match:
            rest = comment_bind_match.group(1).strip()
            # It might be a descriptive comment like "bind = SUPER + ←, -- Focus left"
            # Extract the comment after "--"
            comment_part = ""
            if " -- " in rest:
                comment_part = rest.split(" -- ", 1)[1].strip()
                if is_hidden(comment_part):
                    reading_line += 1
                    continue
            # Try to parse as hl.bind if it starts with hl.bind
            if rest.startswith("hl.bind"):
                kb = parse_lua_bind(rest, override_comment=comment_part)
                if kb:
                    current_content["keybinds"].append(kb)
            elif comment_part:
                # It's a descriptive placeholder like "bind = SUPER + ←/→ -- Focus in direction"
                # Extract key hint from before " -- "
                key_hint = rest.split(" -- ")[0].strip()
                # Clean up "bind = ", "binde = " prefix and trailing commas
                key_hint = re.sub(r'^bind[a-z]*\s*=\s*', '', key_hint)
                key_hint = key_hint.rstrip(',').strip()
                # Clean up specific representations
                key_hint = key_hint.replace("Hash", "1..9")
                key_hint = key_hint.replace("Page_↑/↓", "Page_Up/Down")
                key_hint = key_hint.replace("Scroll ↑/↓", "Scroll Up/Down")
                key_hint = re.sub(r'\b(SUPER|SHIFT|CTRL|ALT)\s*,\s*', r'\1 + ', key_hint)
                key_hint = key_hint.replace("SUPER+SUPER_L", "SUPER + SUPER_L")
                key_hint = key_hint.replace("SUPER+ALT", "SUPER + ALT")
                key_hint = key_hint.replace("SUPER+SHIFT", "SUPER + SHIFT")
                key_hint = key_hint.replace("CTRL+SUPER", "CTRL + SUPER")
                # Build a synthetic KeyBinding for display
                kb = KeyBinding([], key_hint, "comment", "", comment_part)
                current_content["keybinds"].append(kb)
            reading_line += 1
            continue

        # ── Normal hl.bind(...) ───────────────────────────────────────
        if re.match(r'\s*hl\.bind\s*\(', line):
            # Handle multiline binds by collecting until closing paren+bracket
            full_line = line
            depth = full_line.count("(") - full_line.count(")")
            lookahead = reading_line + 1
            while depth > 0 and lookahead < len(content_lines):
                next_line = content_lines[lookahead]
                full_line += " " + next_line.strip()
                depth += next_line.count("(") - next_line.count(")")
                lookahead += 1

            # Check trailing comment for hidden marker
            # e.g. ) -- # [hidden]
            if is_hidden(full_line):
                reading_line = lookahead
                continue

            kb = parse_lua_bind(full_line)
            if kb:
                current_content["keybinds"].append(kb)
            reading_line = lookahead
            continue

        reading_line += 1

    return current_content


def parse_keys(path: str) -> Section:
    global content_lines, reading_line
    raw = read_content(path)
    if raw == "error":
        return Section([], [], "error")
    content_lines = raw.splitlines()
    reading_line  = 0
    return get_binds_recursive(Section([], [], ""), 0)


if __name__ == "__main__":
    result = parse_keys(args.path)
    print(json.dumps(result))