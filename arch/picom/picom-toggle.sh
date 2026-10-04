#!/bin/bash
# ============================================================================
# picom-toggle.sh - start/stop picom on demand, for gaming.
#
# Why a state file: i3 runs 'exec_always picom -f', which re-fires on every
# reload and would silently undo a manual "kill picom before launching a game".
# So the desired state is recorded on disk and exec_always consults it.
#
# Usage:
#   picom-toggle.sh                 toggle, and report the new state
#   picom-toggle.sh on              force on
#   picom-toggle.sh off             force off
#   picom-toggle.sh status          report without changing anything
#   picom-toggle.sh --start-if-enabled
#                                   used by i3 exec_always: honour the
#                                   recorded preference instead of forcing
#                                   picom back on
# ============================================================================
set -u

STATE_DIR="$HOME/.cache/picom"
STATE="$STATE_DIR/enabled"
CONF="$HOME/.config/picom/picom.conf"

mkdir -p "$STATE_DIR"

running() { pgrep -x picom >/dev/null 2>&1; }

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "picom" -t 2500 -u "${2:-low}" "picom" "$1" >/dev/null 2>&1
    fi
}

# Desired state defaults to on when nothing has been recorded yet, which
# matches the out-of-the-box i3 behaviour of starting picom at login.
desired_on() {
    [ -f "$STATE" ] || return 0
    [ "$(cat "$STATE" 2>/dev/null)" = "on" ]
}

start_picom() {
    running && return 0
    # setsid detaches it from i3's process group so an i3 restart does not
    # take the compositor down with it.
    setsid picom --config "$CONF" >/dev/null 2>&1 &
    # Give it a moment so the reported state reflects reality.
    sleep 1
    if running; then
        printf 'on\n' > "$STATE"
        notify "Compositor ON" "low"
        echo "picom: started"
    else
        # Do not record "on" if it failed, or the next reload loops forever.
        echo "picom: FAILED to start - check ~/.config/picom/picom.conf" >&2
        return 1
    fi
}

stop_picom() {
    if ! running; then
        printf 'off\n' > "$STATE"
        echo "picom: already stopped"
        return 0
    fi
    pkill -x picom
    # Wait for it to actually exit so the reported state is truthful.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        running || break
        sleep 0.3
    done
    if running; then
        pkill -9 -x picom 2>/dev/null
        sleep 0.5
    fi
    printf 'off\n' > "$STATE"
    notify "Compositor OFF - best for gaming" "low"
    echo "picom: stopped"
}

case "${1:-toggle}" in
    on|enable)
        start_picom
        ;;

    off|disable)
        stop_picom
        ;;

    toggle)
        if running; then stop_picom; else start_picom; fi
        ;;

    status)
        if running; then echo "picom: running"; else echo "picom: stopped"; fi
        ;;

    --start-if-enabled)
        # This is what i3 exec_always calls. Honour the recorded preference.
        if desired_on; then
            start_picom
        else
            echo "picom: left off by user preference"
        fi
        ;;

    *)
        grep '^#   picom-toggle' "$0" | sed 's/^#   //'
        exit 1
        ;;
esac
