#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" && -f "$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate" ]]; then
    source "$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate"
fi
GIO_USE_VFS=local "$SCRIPT_DIR/thumbgen.py" "$@"
THUMBGEN_EXIT_CODE=$?
if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]] && command -v deactivate >/dev/null 2>&1; then
    deactivate
fi

exit $THUMBGEN_EXIT_CODE
