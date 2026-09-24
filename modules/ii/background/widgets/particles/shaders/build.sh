#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
QSB="${QSB:-$(command -v qsb || echo /usr/lib/qt6/bin/qsb)}"
for style in sakura snow fireflies starfield; do
    "$QSB" --qt6 -o "$style.frag.qsb" "$style.frag"
done
