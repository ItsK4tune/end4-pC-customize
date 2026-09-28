#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
QUICKSHELL_CONFIG_NAME="$(basename "$CONFIG_DIR")"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_kitty() {  
  if [ ! -f "$SCRIPT_DIR/terminal/kitty-theme.conf" ] || [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    return
  fi
  mkdir -p "$STATE_DIR/user/generated/terminal"
  python3 -c '
import sys, os
scss_path, tpl_path, out_path = sys.argv[1:4]
colors = {}
with open(scss_path, "r") as f:
    for line in f:
        line = line.strip()
        if ":" in line and line.endswith(";"):
            p = line.split(":", 1)
            colors[p[0].strip() + " #"] = p[1].split(";")[0].strip().lstrip("#")

with open(tpl_path, "r") as f:
    content = f.read()

for k, v in colors.items():
    content = content.replace(k, v)

tmp_path = out_path + ".tmp"
with open(tmp_path, "w") as f:
    f.write(content)
os.replace(tmp_path, out_path)
' "$STATE_DIR/user/generated/material_colors.scss" "$SCRIPT_DIR/terminal/kitty-theme.conf" "$STATE_DIR/user/generated/terminal/kitty-theme.conf"

  # Reload
  pkill -SIGUSR1 -x kitty 2>/dev/null || true
}

apply_anyterm() {
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ] || [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    return
  fi
  mkdir -p "$STATE_DIR/user/generated/terminal"
  python3 -c '
import sys, os
scss_path, tpl_path, out_path, alpha = sys.argv[1:5]
colors = {}
with open(scss_path, "r") as f:
    for line in f:
        line = line.strip()
        if ":" in line and line.endswith(";"):
            p = line.split(":", 1)
            colors[p[0].strip() + " #"] = p[1].split(";")[0].strip().lstrip("#")

with open(tpl_path, "r") as f:
    content = f.read()

for k, v in colors.items():
    content = content.replace(k, v)

content = content.replace("$alpha", alpha)

tmp_path = out_path + ".tmp"
with open(tmp_path, "w") as f:
    f.write(content)
os.replace(tmp_path, out_path)
' "$STATE_DIR/user/generated/material_colors.scss" "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR/user/generated/terminal/sequences.txt" "$term_alpha"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_term() {
  apply_kitty
  apply_anyterm
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
