#!/bin/bash

IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
if [[ -z "$IFACE" || ! -d "/sys/class/net/$IFACE" ]]; then
    IFACE="$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n 1)"
fi
[[ -z "$IFACE" ]] && exit 0

AC="#9d4edd"
WIFI_ICON=$'\uf1eb'
ARROW_DOWN=$'\uf063'
ARROW_UP=$'\uf062'

if [[ -d "/sys/class/net/$IFACE/wireless" ]]; then
    if nmcli -t -f WIFI radio 2>/dev/null | grep -q "disabled"; then
        echo " %{F$AC}%{T2}${WIFI_ICON}%{T-}%{F-} wifi off"
        exit 0
    fi
    line="$(nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --ifname "$IFACE" 2>/dev/null | grep '^\*' | head -n 1)"
    if [[ -z "$line" ]]; then
        line="$(nmcli -t -f SSID,SIGNAL device wifi list --ifname "$IFACE" 2>/dev/null | head -n 1)"
    fi
    essid="$(echo "$line" | cut -d: -f2)"
    signal="$(echo "$line" | cut -d: -f3)"
    [[ -z "$essid" ]] && essid="--"
    [[ -z "$signal" ]] && signal="0"
    echo " %{F$AC}%{T2}${WIFI_ICON}%{T-}%{F-} $essid ${signal}%"
else
    if ip link show "$IFACE" | grep -q "state UP"; then
        RX1=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")
        TX1=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes")
        sleep 1
        RX2=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")
        TX2=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes")
        RX_KB=$(( (RX2 - RX1) / 1024 ))
        TX_KB=$(( (TX2 - TX1) / 1024 ))
        echo " %{F$AC}%{T2}${ARROW_DOWN}%{T-}%{F-} ${RX_KB}KB/s  %{F$AC}%{T2}${ARROW_UP}%{T-}%{F-} ${TX_KB}KB/s"
    else
        echo " %{F$AC}%{T2}${ARROW_DOWN}%{T-}%{F-} down"
    fi
fi
