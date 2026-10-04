#!/bin/bash

temp="$(sensors 2>/dev/null | awk '/Package id 0:/ {print $4}' | tr -d '+')"
if [[ -z "$temp" ]]; then
    temp="$(sensors 2>/dev/null | awk '/temp1:/ {print $2}' | tr -d '+')"
fi
if [[ -z "$temp" ]]; then
    echo "N/A"
else
    echo "$temp"
fi
