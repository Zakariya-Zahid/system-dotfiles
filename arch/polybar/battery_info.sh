#!/bin/bash

BAT="BAT0"
BATPATH="/sys/class/power_supply/$BAT"

# Detect battery interface
if [ -f "$BATPATH/energy_now" ]; then
    now=$(cat "$BATPATH/energy_now")
    full=$(cat "$BATPATH/energy_full")
elif [ -f "$BATPATH/charge_now" ]; then
    now=$(cat "$BATPATH/charge_now")
    full=$(cat "$BATPATH/charge_full")
else
    echo "Battery info not found"
    exit 1
fi

# Percentage with decimal
percent=$(awk "BEGIN {printf \"%.1f\", ($now/$full)*100}")

# Get charging status
status=$(cat "$BATPATH/status")

# Conditional output based on status
if [ "$status" = "Charging" ]; then
    icon=""
    
    # Only calculate rate and time when charging
    rate=$(upower -i $(upower -e | grep BAT) | awk '/energy-rate/ {printf "%.0f", $2}')
    time=$(upower -i $(upower -e | grep BAT) | awk -F: '/time to/ {print $2}' | sed 's/^ *//')
    
    echo "$icon $percent% | ${rate}W | $time"
else
    # This covers "Discharging", "Full", and "Not charging"
    icon=""
    echo "$icon $percent%"
fi
