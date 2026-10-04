#!/usr/bin/env bash

set -euo pipefail

BG_DIR="$HOME/.config/i3lock/backgrounds"

# Pick a random background if any exist, otherwise fall back to a solid color.
if [[ -d "$BG_DIR" ]]; then
    BG=$(find "$BG_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | shuf -n 1)
fi

ARGS=(
    --insidecolor=00000000
    --ringcolor=88c0d0ff
    --linecolor=00000000
    --keyhlcolor=b48eadff
    --insidevercolor=bf616aff
    --insidewrongcolor=bf616aff
    --ringvercolor=a3be8cff
    --ringwrongcolor=bf616aff
    --verifcolor=d8dee9ff
    --wrongcolor=bf616aff
    --timecolor=d8dee9ff
    --datecolor=88c0d0ff
    --clock
)

if [[ -n "${BG:-}" && -f "$BG" ]]; then
    ARGS+=(--image "$BG")
else
    ARGS+=(--color 1e222a)
fi

exec /usr/bin/i3lock "${ARGS[@]}"
