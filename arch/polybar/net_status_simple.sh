#!/bin/bash
# net_status_simple.sh - compact network status for the polybar network module.
# Outputs a single short status string, e.g. "connected", "HomeWiFi 72%", "offline".

set -u

IFACE="${NET_IFACE:-}"
if [[ -z "$IFACE" || ! -d "/sys/class/net/$IFACE" ]]; then
    IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
fi
if [[ -z "$IFACE" || ! -d "/sys/class/net/$IFACE" ]]; then
    IFACE="$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n 1)"
fi
[[ -z "$IFACE" ]] && { echo "offline"; exit 0; }

# --- Wireless ---------------------------------------------------------------
if [[ -d "/sys/class/net/$IFACE/wireless" ]]; then
    if nmcli -t -f WIFI radio 2>/dev/null | grep -q disabled; then
        echo "offline"
        exit 0
    fi

    # NOTE: `nmcli device wifi list` takes the interface as a POSITIONAL argument
    # ("... list ifname wlan0"). Passing "--ifname wlan0" makes nmcli abort with
    # "invalid extra argument", which used to surface as a permanent "offline".
    # Only IN-USE and SIGNAL are requested so that SSIDs containing ':' (which
    # nmcli escapes as '\:') cannot corrupt the field split.
    signal="$(nmcli -t -f IN-USE,SIGNAL device wifi list ifname "$IFACE" 2>/dev/null \
            | awk -F: '$1 == "*" {print $2; exit}')"

    if [[ -z "$signal" ]]; then
        echo "offline"
    else
        echo "${signal}%"
    fi
    exit 0
fi

# --- Ethernet / wired -------------------------------------------------------
if ip link show "$IFACE" 2>/dev/null | grep -q "state UP"; then
    echo "connected (wired)"
else
    echo "offline"
fi