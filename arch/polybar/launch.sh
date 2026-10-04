#!/bin/bash
# Launch the single polybar bar ("main").
# Logs polybar output to ~/.cache/polybar/polybar.log for debugging.

LOG_DIR="$HOME/.cache/polybar"
mkdir -p "$LOG_DIR"

# Force an English locale for polybar.
# The system's per-category locale is LC_TIME=ur_PK (see /etc/locale.conf), which
# makes strftime render the date module's %p as "ش" instead of AM/PM, and month
# names in Urdu. Removing this line is safe once the system locale is English.
export LC_ALL=en_US.UTF-8

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Expose the active network interface for the network module script.
if [[ -z "${NET_IFACE:-}" ]]; then
    NET_IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
fi
if [[ -z "${NET_IFACE:-}" ]]; then
    NET_IFACE="$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n 1)"
fi
export NET_IFACE

polybar -c ~/.config/polybar/config.ini main >"$LOG_DIR/polybar.log" 2>&1 &
