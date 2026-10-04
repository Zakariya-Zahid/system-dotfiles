#!/usr/bin/env bash

# powermenu.sh - rofi power menu launched from the polybar power button.

set -euo pipefail

choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown\n' | rofi -dmenu -p 'Power')

case "$choice" in
    Lock)     ~/.config/i3lock/lock.sh ;;
    Logout)   i3-msg exit ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
    *)        exit 0 ;;
esac
