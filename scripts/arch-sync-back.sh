#!/usr/bin/env bash

###############################################################################
# arch-sync-back.sh - Pull live configs back into the dotfiles repository.
#
# Copies ~/.config/<dest> back into arch/<src> for every folder in the shared
# CONFIG_MAP. Use this whenever you tweak a config on the machine and want to
# keep the repository up to date, then commit the changes.
#
# This is the reverse of the config-sync step in arch-setup-i3.sh.
###############################################################################

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ARCH_DIR="$REPO_ROOT/arch"

source "$SCRIPT_DIR/config-map.sh"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

# Never copy editor/backup leftovers into the repo, and never let them
# protect stale repo files from deletion either.
EXCLUDES=(
    --exclude='*.bak'
    --exclude='*.bak-*'
    --exclude='*.bak[0-9]*-*'
    --exclude='*.pre-*'
    --exclude='*.orig'
    --exclude='*.swp'
    --exclude='.cache/'
    --exclude='node_modules/'
)

log "Syncing live configs back into $ARCH_DIR"

COPIED=0
for src in "${!CONFIG_MAP[@]}"; do
    dest="${CONFIG_MAP[$src]}"
    LIVE_DIR="$HOME/.config/$dest"
    SRC_DIR="$ARCH_DIR/$src"

    if [[ ! -d "$LIVE_DIR" ]]; then
        warn "~/.config/$dest not found; skipping $src"
        continue
    fi

    mkdir -p "$SRC_DIR"

    # --delete IS wanted here: this direction is "the repo should mirror the
    # machine". Without it, a file deleted on the machine is immortal in the
    # repo and gets reinstalled by arch-setup-i3.sh on the next machine.
    # That is exactly how a dead polybar/autohide.sh survived deletion here.
    # Files matching EXCLUDES are protected from deletion by rsync's default
    # behaviour, so backup files already in the repo are left alone.
    if ! rsync -a --delete "${EXCLUDES[@]}" "$LIVE_DIR/" "$SRC_DIR/"; then
        warn "Failed to sync ~/.config/$dest -> arch/$src"
        continue
    fi

    echo "   -> ~/.config/$dest -> arch/$src"
    COPIED=$((COPIED + 1))
done

# Home-level dotfiles: pull back only the files the repo already tracks.
HOME_SRC="$ARCH_DIR/home"
if [[ -d "$HOME_SRC" ]]; then
    while IFS= read -r -d '' f; do
        base="$(basename "$f")"
        if [[ -f "$HOME/$base" ]]; then
            cp -a "$HOME/$base" "$f"
            echo "   -> ~/$base -> arch/home/"
            COPIED=$((COPIED + 1))
        fi
    done < <(find "$HOME_SRC" -maxdepth 1 -type f -print0)
fi

###############################################################################
# Post-sync sanity checks.
#
# Every one of these catches a bug that actually shipped in this repo:
#   - CRLF shebangs made 17 scripts fail to exec on a fresh clone, so the
#     polybar modules and i3lock silently did nothing.
#   - i3 exec_always lines pointing at scripts that are not in the repo
#     produced "bad interpreter" errors on every login.
#   - Endless polling loops started by exec_always accumulate one copy per
#     reload, which pinned the CPU at 87C and stopped the battery charging.
###############################################################################
log "Sanity checks"

PROBLEMS=0
report() { printf '   FAIL  %s\n' "$*" >&2; PROBLEMS=$((PROBLEMS + 1)); }

# 1. CRLF anywhere in a tracked file. Most configs tolerate it, but a CRLF
#    shebang is fatal ("bad interpreter"), and it is how 17 scripts in this
#    repo managed to be non-functional on a fresh clone.
while IFS= read -r -d '' f; do
    rel="${f#"$ARCH_DIR"/}"
    if grep -qU $'\r' "$f" 2>/dev/null; then
        if head -1 "$f" | grep -q $'\r'; then
            report "CRLF shebang (will not exec): $rel"
        else
            report "CRLF line endings: $rel"
        fi
    fi
done < <(find "$ARCH_DIR" -type f ! -path '*/spicetify/*' -print0)

# 2. i3 exec/exec_always targets that do not exist in the repo.
if [[ -f "$ARCH_DIR/i3/config" ]]; then
    while read -r _ target; do
        [[ -z "$target" ]] && continue
        case "$target" in
            ~*) resolved="$ARCH_DIR/home/.${target#~/}" ;;
            /*) resolved="$target" ;;
            *)  resolved="$ARCH_DIR/i3/$target" ;;
        esac
        [[ -e "$resolved" ]] || report "i3 config runs missing file: $target"
    done < <(grep -oE '^[[:space:]]*exec(_always)?[[:space:]]+(--no-startup-id[[:space:]]+)?~?[^[:space:]]+' \
                 "$ARCH_DIR/i3/config" | awk '{print $NF}')
fi

# 3. Endless loops in scripts that i3 starts on every reload.
for f in $(grep -rlE '^[[:space:]]*while[[:space:]]+true' "$ARCH_DIR" \
             --include='*.sh' --exclude-dir=spicetify 2>/dev/null); do
    base="$(basename "$f")"
    if grep -q "$base" "$ARCH_DIR/i3/config" 2>/dev/null; then
        report "endless loop started by i3 exec_always: ${f#"$ARCH_DIR"/}"
    fi
done

if (( PROBLEMS == 0 )); then
    echo "   OK    no CRLF line endings, no dangling i3 exec targets, no i3-started endless loops"
else
    warn "$PROBLEMS problem(s) found - fix these before committing"
fi

log "Done. ${COPIED} folder(s) synced."
echo
echo "Review the changes and commit them:"
echo "  git -C $REPO_ROOT status"
echo "  git -C $REPO_ROOT add arch/"
echo "  git -C $REPO_ROOT commit -m \"config: update ...\""
