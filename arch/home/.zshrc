# zsh configuration - deployed from systems-dotfiles (arch/home/.zshrc)

# --- Powerlevel10k instant prompt (must be first) ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Powerlevel10k theme (AUR package: zsh-theme-powerlevel10k) ---
export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
if [[ -r /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]]; then
    source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
fi

# --- Powerlevel10k config (lean style) ---
if [[ -r "$HOME/.p10k.zsh" ]]; then
    source "$HOME/.p10k.zsh"
fi

# Editor
[[ -z "${EDITOR:-}" ]] && export EDITOR=nvim

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS

# Common aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'

# opencode
export PATH=/home/zak/.opencode/bin:$PATH
