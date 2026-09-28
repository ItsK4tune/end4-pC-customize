#!/usr/bin/env bash
PIDFILE="/tmp/focus_ambient_mpv.pid"

kill_existing() {
    if [[ -f "$PIDFILE" ]]; then
        old_pid=$(cat "$PIDFILE" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
    pkill -f "mpv.*focus-ambient-lavfi" 2>/dev/null
}

action="${1:-stop}"
sound="${2:-rain}"
vol="${3:-75}"

case "$action" in
    stop)
        kill_existing
        ;;
    chime)
        # Play a soft 528Hz Solfeggio bell chime that fades out
        mpv --no-video --keep-open=no --title="focus-chime" \
            "av://lavfi:sine=frequency=528:duration=1.8,afade=t=out:st=0.8:d=1.0,volume=0.5" >/dev/null 2>&1 &
        ;;
    play)
        kill_existing

        lavfi=""
        case "$sound" in
            rain)
                lavfi="anoisesrc=color=pink:amplitude=0.32,lowpass=f=2600"
                ;;
            waves)
                lavfi="anoisesrc=color=brown:amplitude=0.45,lowpass=f=1800"
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

        if [[ -n "$lavfi" ]]; then
            mpv --no-video --volume="$vol" --title="focus-ambient-lavfi" \
                "av://lavfi:${lavfi}" >/dev/null 2>&1 &
            echo $! > "$PIDFILE"
        fi
        ;;
esac
