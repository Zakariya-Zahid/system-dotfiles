#!/bin/bash

AC="#9d4edd"
BAT_FULL=$'\uf240'
BAT_THREE=$'\uf241'
BAT_HALF=$'\uf242'
BAT_QUARTER=$'\uf243'
BAT_LOW=$'\uf244'
BAT_EMPTY=$'\uf245'
CHARGING=$'\uf0e7'

BAT_PATH="/sys/class/power_supply/BAT0"

if [[ ! -d "$BAT_PATH" ]]; then
    echo "%{F$AC}%{T2}${CHARGING}%{T-}%{F-} AC"
    exit 0
fi

status="$(cat "$BAT_PATH/status" 2>/dev/null)"
capacity="$(cat "$BAT_PATH/capacity" 2>/dev/null)"

[[ -z "$capacity" ]] && exit 0

if [[ "$status" == "Charging" ]]; then
    icon="$CHARGING"
elif (( capacity >= 90 )); then
    icon="$BAT_FULL"
elif (( capacity >= 65 )); then
    icon="$BAT_THREE"
elif (( capacity >= 40 )); then
    icon="$BAT_HALF"
elif (( capacity >= 20 )); then
    icon="$BAT_QUARTER"
else
    icon="$BAT_LOW"
fi

echo "%{F$AC}%{T2}${icon}%{T-}%{F-} ${capacity}%"
