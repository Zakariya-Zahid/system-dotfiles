#!/bin/bash

set -euo pipefail

# Use the interface on the default route, otherwise the first non-loopback one.
INTERFACE="${1:-}"
if [[ -z "$INTERFACE" ]]; then
    INTERFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
fi
if [[ -z "$INTERFACE" || ! -d "/sys/class/net/$INTERFACE" ]]; then
    INTERFACE="$(ls /sys/class/net 2>/dev/null | grep -v '^lo$' | head -n 1)"
fi

if [[ -z "$INTERFACE" ]]; then
    exit 0
fi

RX1=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes")
TX1=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes")

sleep 1

RX2=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes")
TX2=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes")

RX_RATE=$((RX2 - RX1))
TX_RATE=$((TX2 - TX1))

RX_KB=$((RX_RATE / 1024))
TX_KB=$((TX_RATE / 1024))

echo "↓ ${RX_KB}KB/s ↑ ${TX_KB}KB/s"
