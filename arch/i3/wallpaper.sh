#!/bin/bash
# ============================================================================
# wallpaper.sh - wallpaper management for i3 on X11, using feh + rofi.
#
# feh is a one-shot tool: it paints the root window once and then has no idea
# what it drew. That is why the old setup looked fine until something caused a
# root repaint, and why there was no way to change the wallpaper. This wrapper
# keeps the current image in a state file so it can be re-applied after an
# i3 reload, and adds browsing / next / prev / random.
#
# Usage:
#   wallpaper.sh pick            browse and choose with rofi
#   wallpaper.sh next|prev       step through the list
#   wallpaper.sh random          pick a random one
#   wallpaper.sh set <file>      set a specific image
#   wallpaper.sh fit <mode>      re-apply with fill|scale|center|tile
#   wallpaper.sh restore         re-apply the remembered one (used by i3)
#   wallpaper.sh path            print the current wallpaper
#   wallpaper.sh dir             print (and create) the wallpaper directory
# ============================================================================
set -u

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
STATE_DIR="$HOME/.cache/wallpaper"
STATE="$STATE_DIR/current"
FIT_FILE="$STATE_DIR/fit"

mkdir -p "$WALL_DIR" "$STATE_DIR"

# Image types we accept.
#
# Deliberately -iname predicates rather than a single -iregex: this system's
# find is 4.11.0-modified and silently matches nothing for a regex containing
# an alternation group. Verified: -iregex '.*\.jpg$' returns 4 files, but
# -iregex '.*\.(jpg|jpeg)$' returns 0.
IMAGE_ARGS=(
    -iname '*.jpg'  -o -iname '*.jpeg' -o -iname '*.png'
    -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.jfif'
    -o -iname '*.avif'
)

# ---------------------------------------------------------------------------

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "wallpaper" -t 4000 -u "${2:-low}" "Wallpaper" "$1" >/dev/null 2>&1
    fi
}

list_walls() {
    find "$WALL_DIR" -type f \( "${IMAGE_ARGS[@]}" \) 2>/dev/null | sort
}

count_walls() {
    list_walls | wc -l
}

# Apply an image to the root window and record it as the current wallpaper.
apply() {
    local img="$1" fit="${2:-fill}" flag

    [ -f "$img" ] || { notify "No such file: $img" "critical"; return 1; }

    case "$fit" in
        fill)   flag="--bg-fill"   ;;
        scale)  flag="--bg-scale"  ;;
        center) flag="--bg-center" ;;
        tile)   flag="--bg-tile"   ;;
        *)      flag="--bg-fill"; fit="fill" ;;
    esac

    # --no-fehbg because we maintain the state file ourselves; letting feh
    # write ~/.fehbg too would leave two sources of truth that can disagree.
    if feh --no-fehbg "$flag" "$img"; then
        printf '%s\n' "$img" > "$STATE"
        printf '%s\n' "$fit"  > "$FIT_FILE"
        # A plain shell one-liner, so the wallpaper can also be restored by
        # feh --bg-fill "$(cat ~/.fehbg)" style tooling if that ever changes.
        printf "#!/bin/sh\nfeh --no-fehbg %s '%s'\n" "$flag" "$img" > "$HOME/.fehbg"
        chmod +x "$HOME/.fehbg" 2>/dev/null
        notify "$(basename "$img")"
        return 0
    fi

    notify "feh failed to set the wallpaper" "critical"
    return 1
}

# Pick the neighbouring entry relative to the current one.
step() {
    local dir="$1" n
    n=$(count_walls)
    [ "$n" -gt 0 ] || { notify "No images in $WALL_DIR" "critical"; return 1; }

    local -a arr
    mapfile -t arr < <(list_walls)
    local cur=-1 i
    for i in "${!arr[@]}"; do
        [ "${arr[$i]}" = "$(cat "$STATE" 2>/dev/null)" ] && { cur=$i; break; }
    done

    local next
    if [ "$dir" = "next" ]; then
        next=$(( (cur + 1) % n ))
    else
        [ "$cur" -lt 0 ] && next=0 || next=$(( (cur - 1 + n) % n ))
    fi

    apply "${arr[$next]}" "$(cat "$FIT_FILE" 2>/dev/null || echo fill)"
}

# ---------------------------------------------------------------------------

case "${1:-}" in
    pick)
        [ "$(count_walls)" -gt 0 ] || {
            notify "No images in $WALL_DIR - drop some in and try again" "normal"
            exit 0
        }
        chosen=$(list_walls | rofi -show-icons -i -no-custom \
                     -p "Wallpaper" -theme-str 'window {width: 60%;}' 2>/dev/null)
        [ -n "$chosen" ] && apply "$chosen" "$(cat "$FIT_FILE" 2>/dev/null || echo fill)"
        ;;

    next|prev)
        step "$1"
        ;;

    random)
        [ "$(count_walls)" -gt 0 ] || { notify "No images in $WALL_DIR" "normal"; exit 0; }
        apply "$(list_walls | shuf -n 1)" "$(cat "$FIT_FILE" 2>/dev/null || echo fill)"
        ;;

    set)
        [ -n "${2:-}" ] || { echo "usage: wallpaper.sh set <file>" >&2; exit 1; }
        apply "$2" "${3:-$(cat "$FIT_FILE" 2>/dev/null || echo fill)}"
        ;;

    fit)
        cur=$(cat "$STATE" 2>/dev/null)
        if [ -z "$cur" ]; then
            notify "No wallpaper set yet" "normal"
            exit 0
        fi
        apply "$cur" "${2:-fill}"
        ;;

    restore)
        cur=$(cat "$STATE" 2>/dev/null)
        if [ -z "$cur" ] || [ ! -f "$cur" ]; then
            # First run, or the remembered file was deleted. Fall back to
            # whatever single image exists rather than leaving a black root.
            first=$(list_walls | head -n 1)
            if [ -n "$first" ]; then
                apply "$first" "$(cat "$FIT_FILE" 2>/dev/null || echo fill)"
            else
                # Nothing to show, and do NOT silently do nothing - that is
                # exactly what hid this problem before.
                notify "No wallpapers in $WALL_DIR - desktop will stay empty" "normal"
            fi
        else
            apply "$cur" "$(cat "$FIT_FILE" 2>/dev/null || echo fill)"
        fi
        ;;

    path)
        cat "$STATE" 2>/dev/null
        ;;

    dir)
        echo "$WALL_DIR"
        ;;

    *)
        grep '^#   wallpaper' "$0" | sed 's/^#   //'
        ;;
esac
