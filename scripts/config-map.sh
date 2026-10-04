#!/usr/bin/env bash
# Shared mapping between arch/<source> folders and ~/.config/<dest> names.
# Sourced by both the setup and sync-back scripts.

declare -A CONFIG_MAP=(
    [i3]="i3"
    [i3lock]="i3lock"
    [kitty]="kitty"
    [neovim]="nvim"
    [picom]="picom"
    [polybar]="polybar"
    [rofi]="rofi"
    [dunst]="dunst"
)
