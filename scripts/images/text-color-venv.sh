#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" && -f "$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate" ]]; then
    source "$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate"
fi
"$SCRIPT_DIR/text_color.py" "$@"
if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]] && command -v deactivate >/dev/null 2>&1; then
    deactivate
fi
