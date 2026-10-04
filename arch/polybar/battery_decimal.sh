#!/bin/bash

now=$(cat /sys/class/power_supply/BAT0/energy_now)
full=$(cat /sys/class/power_supply/BAT0/energy_full)

percent=$(awk "BEGIN {printf \"%.1f\", ($now/$full)*100}")

echo "$percent%"
