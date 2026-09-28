#!/usr/bin/env bash
PIDFILE="/tmp/focus_ambient_mpv.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOUNDS_DIR="$SCRIPT_DIR/assets/sounds"

kill_existing() {
    if [[ -f "$PIDFILE" ]]; then
        old_pid=$(cat "$PIDFILE" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
    pkill -f "mpv.*focus-ambient" 2>/dev/null
}

action="${1:-stop}"
sound="${2:-rain}"
vol="${3:-75}"

case "$action" in
    stop)
        kill_existing
        ;;
    chime)
        if [[ -f "$SOUNDS_DIR/chime.ogg" ]]; then
            mpv --no-video --keep-open=no --volume=85 --title="focus-ambient-chime" \
                "$SOUNDS_DIR/chime.ogg" >/dev/null 2>&1 &
        else
            mpv --no-video --keep-open=no --volume=60 --title="focus-ambient-chime" \
                "av://lavfi:sine=frequency=528:duration=1.8,afade=t=out:st=0.8:d=1.0" >/dev/null 2>&1 &
        fi
        ;;
    play)
        kill_existing

        audio_file=""
        case "$sound" in
            rain)
                audio_file="$SOUNDS_DIR/rain.ogg"
                ;;
            waves|ocean)
                audio_file="$SOUNDS_DIR/waves.ogg"
                ;;
            brook|stream)
                audio_file="$SOUNDS_DIR/brook.ogg"
                ;;
            fireplace|fire)
                audio_file="$SOUNDS_DIR/fireplace.ogg"
                ;;
            alpha)
                lavfi="sine=frequency=216:sample_rate=44100[l];sine=frequency=226:sample_rate=44100[r];[l][r]amerge=inputs=2,volume=0.4"
                ;;
            theta)
                lavfi="sine=frequency=216:sample_rate=44100[l];sine=frequency=222:sample_rate=44100[r];[l][r]amerge=inputs=2,volume=0.4"
                ;;
            *)
                exit 0
                ;;
        esac

        if [[ -n "$audio_file" && -f "$audio_file" ]]; then
            mpv --no-video --loop=inf --volume="$vol" --title="focus-ambient-loop" \
                "$audio_file" >/dev/null 2>&1 &
            echo $! > "$PIDFILE"
        elif [[ -n "$lavfi" ]]; then
            mpv --no-video --volume="$vol" --title="focus-ambient-lavfi" \
                "av://lavfi:${lavfi}" >/dev/null 2>&1 &
            echo $! > "$PIDFILE"
        fi
        ;;
esac

