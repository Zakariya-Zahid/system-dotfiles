#!/usr/bin/env bash

###############################################################################
# arch-setup-i3.sh - Idempotent Arch Linux setup for i3 + polybar + dotfiles
#
# Installs packages (official + AUR) and syncs the configs from this
# repository into ~/.config. Safe to re-run at any time.
#
# Package lists in pkglist/ are grouped into sections:
#   [core]   Always installed (required for the setup to work).
#   [other]  Optional; you are asked which groups to install so you get your
#            own flavor of setup.
#
# Flags:
#   --skip-update      Do not run `pacman -Syu` first
#   --skip-packages    Do not install/refresh packages
#   --skip-config      Do not sync configuration files
#   --groups=<list>    Skip prompts; install these groups (e.g. --groups=dev,media).
#                      "core" is always included. "all" = everything.
#   --core-only        Skip prompts; install only [core] sections.
#   -h, --help         Show this help and exit
###############################################################################

set -Eeuo pipefail

# ---------------------------------------------------------------- paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PKGLIST_DIR="$REPO_ROOT/pkglist"
ARCH_DIR="$REPO_ROOT/arch"

# ---------------------------------------------------------------- config map
source "$SCRIPT_DIR/config-map.sh"

# ---------------------------------------------------------------- options
SKIP_UPDATE=false
SKIP_PACKAGES=false
SKIP_CONFIG=false
GROUPS_ARG=""

usage() {
    sed -n '2,19p' "${BASH_SOURCE[0]}"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-update)    SKIP_UPDATE=true ;;
        --skip-packages)  SKIP_PACKAGES=true ;;
        --skip-config)    SKIP_CONFIG=true ;;
        --groups=*)       GROUPS_ARG="${1#*=}" ;;
        --core-only)      GROUPS_ARG="core" ;;
        -h|--help)        usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
    shift
done

# ---------------------------------------------------------------- helpers
log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Install repo packages without ever aborting the run.
#
# pacman resolves every target before it touches the system, so one unknown
# name aborts the whole transaction and -- with `set -e` below -- would kill
# the script before the config sync ever runs. Screen the names first with
# `pacman -Spp` (resolves from the sync DBs, needs no root, installs nothing),
# drop the unknown ones, then install what is left.
install_pkgs() {
    local -a valid=() unknown=()
    local p

    for p in "$@"; do
        if pacman -Spp "$p" &>/dev/null; then
            valid+=("$p")
        else
            unknown+=("$p")
        fi
    done

    if (( ${#unknown[@]} )); then
        warn "Skipping unknown package(s): ${unknown[*]}"
    fi
    if (( ${#valid[@]} == 0 )); then
        warn "Nothing left to install out of: $*"
        return 0
    fi

    sudo pacman -S --needed --noconfirm "${valid[@]}" \
        || warn "pacman reported a failure while installing: ${valid[*]}"
}

# ---------------------------------------------------------------- checks
[[ -f /etc/arch-release ]] || die "This script is intended for Arch Linux only."
# No git required: REPO_ROOT is derived from this script's own location, and
# everything below reads PKGLIST_DIR/ARCH_DIR off it. Check what is needed.
[[ -d "$PKGLIST_DIR" ]] || die "Package list directory not found: $PKGLIST_DIR"
[[ -d "$ARCH_DIR" ]]    || die "Config directory not found: $ARCH_DIR"

# Prompt for sudo now so the rest of the script runs without interruptions.
sudo -v

# Keep sudo alive while the script runs.
(
    while true; do
        sudo -n true
        sleep 60
    done
) &
SUDO_PID=$!

cleanup() {
    kill "$SUDO_PID" 2>/dev/null || true
    for dir in "${CLEANUP_DIRS[@]:-}"; do
        rm -rf "$dir"
    done
}
CLEANUP_DIRS=()
trap cleanup EXIT

# ---------------------------------------------------------------- pkglist
# Parse a section-grouped pkglist file into:
#   PKG_SECTIONS    - ordered list of section names
#   PKG_BY_SECTION  - assoc: section -> "pkg1 pkg2 ..."
parse_pkglist() {
    local file="$1"
    PKG_SECTIONS=()
    declare -gA PKG_BY_SECTION

    [[ -f "$file" ]] || return 0

    local section=""
    while IFS= read -r line; do
        line="${line%%#*}"                       # strip inline comments
        line="${line//[$'\t\r ']/}"              # strip whitespace
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            [[ " ${PKG_SECTIONS[*]} " != *" $section "* ]] && PKG_SECTIONS+=("$section")
            PKG_BY_SECTION["$section"]=""
        elif [[ -n "$section" ]]; then
            PKG_BY_SECTION["$section"]+=" $line"
        fi
    done < "$file"
}

# ---------------------------------------------------------------- group select
# Interactively choose which optional groups to install. Core is always kept.
select_groups() {
    local -a optional=()
    local s
    for s in "${PKG_SECTIONS[@]}"; do
        [[ "$s" != "core" ]] && optional+=("$s")
    done

    if (( ${#optional[@]} == 0 )); then
        GROUPS_ARG="core"
        return
    fi

    echo
    echo "Optional package groups detected:"
    local i=0 pkg count
    for s in "${optional[@]}"; do
        i=$((i + 1))
        count=$(wc -w <<< "${PKG_BY_SECTION[$s]}")
        # Pretty-print first few package names
        pkg="${PKG_BY_SECTION[$s]}"
        echo "  [$i] ${s}  (${count} pkgs: ${pkg# }...)"
    done
    echo "  [a] Install ALL optional groups"
    echo "  [n] Core packages only"

    while true; do
        read -rp "Select groups to install (comma-separated numbers, 'a' all, 'n' none) [n]: " choice
        choice="${choice:-n}"
        case "$choice" in
            a|A)
                GROUPS_ARG="core"
                for s in "${optional[@]}"; do GROUPS_ARG+=",$s"; done
                return
                ;;
            n|N)
                GROUPS_ARG="core"
                return
                ;;
            *)
                GROUPS_ARG="core"
                local ok=true
                IFS=',' read -r -a sel <<< "$choice"
                local idx
                for idx in "${sel[@]}"; do
                    idx="${idx// /}"
                    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#optional[@]} )); then
                        GROUPS_ARG+=",${optional[idx-1]}"
                    else
                        ok=false
                        warn "Invalid choice: $idx"
                    fi
                done
                if [[ "$ok" == true ]]; then
                    return
                fi
                ;;
        esac
    done
}

# Print each selected group's package count (for the log).
selected_groups_log() {
    local IFS=',' s
    for s in $GROUPS_ARG; do
        [[ -n "${PKG_BY_SECTION[$s]:-}" ]] && echo "     - $s: $(wc -w <<< "${PKG_BY_SECTION[$s]}") pkg(s)"
    done
}

# ---------------------------------------------------------------- update
if [[ $SKIP_UPDATE == false ]]; then
    log "Updating system..."
    sudo pacman -Syu --noconfirm
else
    log "Skipping system update."
fi

# ---------------------------------------------------------------- base tools
log "Installing base tools..."
install_pkgs git base-devel rsync

# ---------------------------------------------------------------- packages
if [[ $SKIP_PACKAGES == false ]]; then

    # ---- official ----------------------------------------------------
    parse_pkglist "$PKGLIST_DIR/pacman.txt"
    if (( ${#PKG_SECTIONS[@]} == 0 )); then
        warn "$PKGLIST_DIR/pacman.txt not found or empty; skipping official packages."
    else
        log "Official packages detected (sections: ${PKG_SECTIONS[*]})"
        [[ -n "$GROUPS_ARG" ]] || select_groups
        selected_groups_log

        IFS=',' read -r -a SELECTED <<< "$GROUPS_ARG"
        for s in "${SELECTED[@]}"; do
            [[ -z "${PKG_BY_SECTION[$s]:-}" ]] && continue
            log "Installing official packages: [$s]"
            read -r -a pkgs <<< "${PKG_BY_SECTION[$s]}"
            install_pkgs "${pkgs[@]}"
        done
    fi

    # ---- yay ---------------------------------------------------------
    if command -v yay &>/dev/null; then
        log "yay is already installed."
    else
        log "Installing yay..."
        TEMP_DIR="$(mktemp -d)"
        CLEANUP_DIRS+=("$TEMP_DIR")

        # AUR helper failures must not block the config sync below.
        if git clone --depth 1 https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"; then
            pushd "$TEMP_DIR/yay" >/dev/null
            makepkg -si --noconfirm || warn "makepkg failed while building yay."
            popd >/dev/null
        else
            warn "Failed to clone yay. Check network connectivity."
        fi

        command -v yay &>/dev/null \
            || warn "yay is unavailable; skipping the AUR package section."
    fi

    # ---- AUR ---------------------------------------------------------
    if ! command -v yay &>/dev/null; then
        warn "yay not found; skipping AUR packages."
    else
        parse_pkglist "$PKGLIST_DIR/aur.txt"
        if (( ${#PKG_SECTIONS[@]} == 0 )); then
            warn "$PKGLIST_DIR/aur.txt not found or empty; skipping AUR packages."
        else
            log "AUR packages detected (sections: ${PKG_SECTIONS[*]})"
            IFS=',' read -r -a SELECTED <<< "$GROUPS_ARG"
            for s in "${SELECTED[@]}"; do
                [[ -z "${PKG_BY_SECTION[$s]:-}" ]] && continue
                log "Installing AUR packages: [$s]"
                read -r -a pkgs <<< "${PKG_BY_SECTION[$s]}"
                yay -S --needed --noconfirm "${pkgs[@]}" \
                    || warn "yay reported a failure while installing: ${pkgs[*]}"
            done
        fi
    fi

else
    log "Skipping package installation."
fi

# ---------------------------------------------------------------- default shell
if command -v zsh &>/dev/null && [[ "${SHELL:-}" != */zsh ]]; then
    log "Setting default shell to zsh..."
    sudo chsh -s /usr/bin/zsh "$USER" \
        || warn "Could not change default shell; run manually: chsh -s /usr/bin/zsh"
else
    log "zsh is already the default shell."
fi

# ---------------------------------------------------------------- config sync
if [[ $SKIP_CONFIG == false ]]; then

    log "Syncing configuration files..."

    # base tools are no longer fatal, so make the one hard dependency explicit.
    command -v rsync &>/dev/null \
        || die "rsync is required for config sync but is not installed."

    SYNCED=()
    SKIPPED=()

    # Protect local backups on the destination from --delete. Without these,
    # re-running this script on a machine that has .bak files in ~/.config
    # would silently delete them.
    SYNC_EXCLUDES=(
        --exclude='*.bak'
        --exclude='*.bak-*'
        --exclude='*.bak[0-9]*-*'
        --exclude='*.pre-*'
        --exclude='*.orig'
        --exclude='*.swp'
    )

    for src in "${!CONFIG_MAP[@]}"; do
        dest="${CONFIG_MAP[$src]}"
        SRC_DIR="$ARCH_DIR/$src"
        DEST_DIR="$HOME/.config/$dest"

        if [[ ! -d "$SRC_DIR" ]]; then
            SKIPPED+=("$src")
            warn "Source directory missing: $SRC_DIR"
            continue
        fi

        mkdir -p "$DEST_DIR"

        if ! rsync -a --delete "${SYNC_EXCLUDES[@]}" "$SRC_DIR/" "$DEST_DIR/"; then
            warn "Failed to sync $src -> $DEST_DIR"
            continue
        fi

        chmod +x "$DEST_DIR"/*.sh "$DEST_DIR"/*.py 2>/dev/null || true

        SYNCED+=("$dest")
        echo "   -> $src -> ~/.config/$dest"
    done

    if (( ${#SKIPPED[@]} > 0 )); then
        warn "Skipped missing sources: ${SKIPPED[*]}"
    fi

    HOME_SRC="$ARCH_DIR/home"
    if [[ -d "$HOME_SRC" ]]; then
        if rsync -a "$HOME_SRC/" "$HOME/"; then
            echo "   -> home dotfiles -> $HOME"
        else
            warn "Failed to sync home dotfiles."
        fi
    fi

    # ------------------------------------------------------------ validation
    log "Validating configuration..."

    if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
        echo "   -> nvim: config present"
    else
        warn "nvim: ~/.config/nvim/init.lua not found - Neovim settings will not load."
    fi

    if command -v i3 &>/dev/null && [[ -f "$HOME/.config/i3/config" ]]; then
        if i3 -C "$HOME/.config/i3/config" >/dev/null 2>&1; then
            echo "   -> i3: config OK"
        else
            warn "i3: config check failed - run 'i3 -C ~/.config/i3/config' for details."
        fi
    fi

    POLYBAR_CONF="$HOME/.config/polybar/config.ini"
    if [[ -f "$POLYBAR_CONF" ]]; then
        echo "   -> polybar: config present"
        missing=0
        while IFS= read -r exec_line; do
            exec_line="${exec_line#exec = }"
            exec_path="${exec_line//\~/$HOME}"
            [[ "$exec_path" != /* ]] && exec_path="$HOME/$exec_path"
            if [[ -z "$exec_line" ]]; then
                continue
            elif [[ ! -f "$exec_path" ]]; then
                warn "polybar: referenced script not found: $exec_line"
                missing=1
            fi
        done < <(grep -E '^exec = ' "$POLYBAR_CONF")
        (( missing )) || echo "   -> polybar: all referenced scripts OK"
    else
        warn "polybar: $POLYBAR_CONF not found."
    fi

    echo
    echo "Synced ${#SYNCED[@]} configuration folder(s)."

else
    log "Skipping configuration sync."
fi

# ---------------------------------------------------------------- done
echo
echo "========================================"
echo "Setup completed successfully!"
echo
if [[ $SKIP_CONFIG == false ]]; then
    echo "Configs were synced to ~/.config."
    echo "Restart your session or reboot to apply them."
    echo "  - i3:      press Mod+Shift+r to restart i3 in place"
    echo "  - polybar: ~/.config/polybar/launch.sh"
fi
echo "========================================"
