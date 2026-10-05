# systems-dotfiles

A collection of dotfiles and setup scripts for Arch Linux, optimized for i3 + Polybar.

## Repository Structure

- `arch/`: Core configuration files for various applications. Each subfolder is synced to `~/.config/<name>`:
    - `i3/`, `i3lock/`, `kitty/`, `picom/`, `polybar/`, `rofi/`, `dunst/`
    - `neovim/` -> synced to `~/.config/nvim` (Neovim's actual config directory).
    - `home/` -> home-level dotfiles synced to `$HOME` (e.g. `.zshrc`).
- `pkglist/`:
    - `pacman.txt`: Official Arch Linux packages, grouped into `[core]` (always
      installed) and optional sections.
    - `aur.txt`: AUR packages managed by `yay`, grouped the same way.
- `scripts/`: Implementation scripts for system setup.
    - `arch-setup-i3.sh`: Installs packages and pushes configs from `arch/` into `~/.config`.
    - `arch-sync-back.sh`: Pulls your live `~/.config` edits back into `arch/`.
    - `config-map.sh`: Shared mapping of `arch/<source>` -> `~/.config/<dest>` folders.

## Screenshots
<img width="1920" height="1080" alt="fastfetch" src="https://github.com/user-attachments/assets/f43b8bbe-59cf-48bd-8eb6-88f393c0ed3c" />
<img width="1920" height="1080" alt="Desktop" src="https://github.com/user-attachments/assets/5d483012-754f-47dc-b81b-949ee7b4a2df" />
<img width="1080" height="608" alt="image" src="https://github.com/user-attachments/assets/bce4c816-3954-4bdc-ba26-09263caaa20d" />



## Setup Instructions

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Zakariya-Zahid/systems-dotfiles
    cd systems-dotfiles
    ```

2.  **Run the setup script**:
    ```bash
    chmod +x scripts/arch-setup-i3.sh
    ./scripts/arch-setup-i3.sh
    ```

    During package installation you will be asked which optional groups you
    want (e.g. `dev`, `media`, `android`). The `[core]` sections are always
    installed because the i3/polybar setup needs them.

3.  **Restart your session** (or reboot) so the new configs are picked up.

The script is idempotent — safe to re-run any time. Useful options:

```bash
./scripts/arch-setup-i3.sh --help                  # show all options
./scripts/arch-setup-i3.sh --skip-packages         # only sync/validate configs
./scripts/arch-setup-i3.sh --skip-config           # only install/update packages
./scripts/arch-setup-i3.sh --core-only             # install only [core] packages
./scripts/arch-setup-i3.sh --groups=dev,media      # pick groups without prompting
```

## Package Groups

`pkglist/pacman.txt` and `pkglist/aur.txt` use `[section]` headers. `[core]`
sections are always installed; everything else is optional and prompted for.
Run `--groups=all` to install everything, or pass specific groups with
`--groups=<a,b,c>`.

## Polybar Layout

A single full-width "pill" bar (`[bar/main]`, 32px tall, radius 8):

```
╭───────────────────────────────────────────────────────────────────────────────────────╮
│    CPU: 23%     RAM: 4/16G     Temp: 35 C 1  2  3  4  5  6  7  8  9  10     10:40 │   Bat: 80%  │    Vol: 40%  │    connected │
│   └─ modules-left ─────────────┘   └──── modules-center ────┘  └──── modules-right ────┘     │
╰───────────────────────────────────────────────────────────────────────────────────────╯
```

| Zone | Modules |
|------|---------|
| `modules-left` | `cpu`, `memory`, `cpu_temp` |
| `modules-center` | `i3` (workspace numbers, focused one highlighted) |
| `modules-right` | `date`, `battery`, `volume`, `network` |

Scripts in `arch/polybar/` (only these are wired into `config.ini`):
- `launch.sh` - starts the `main` bar; detects the active network interface and logs to `~/.cache/polybar/polybar.log`.
- `net_status_simple.sh` - compact network status: `connected <SSID> <signal>%` / `connected (wired)` / `offline` (uses `nmcli`).
- `cpu_temp.sh` - CPU temperature (requires `lm_sensors`).
- `powermenu.sh` - rofi menu with Lock / Logout / Suspend / Reboot / Shutdown.
- `autohide.sh`, `mouse-trigger.sh`, `fullscreen-hide.py` - auto-hide behavior (requires `xdotool`, `xorg-xprop`).

Icons use `Font Awesome 5 Free` to match `otf-font-awesome`. If you switch to a
newer Font Awesome package, update `font-1`/`font-2` in `config.ini` or the glyphs
render as empty boxes.

## Shell (powerlevel10k)

`arch/home/.zshrc` loads the Powerlevel10k theme and `arch/home/.p10k.zsh`,
a **lean**-style prompt tuned for developers: git status, command duration,
exit status, runtime versions (Python/Go/Node), kube context, and time, with
a transient prompt and instant prompt enabled.

## Two-Way Config Workflow

The repository is the source of truth. `arch-setup-i3.sh` **pushes** configs
from the repo into `~/.config` (one-way). If you edit a config live on the
machine, capture it back into the repo:

```bash
./scripts/arch-sync-back.sh   # pull ~/.config changes back into arch/
git status                     # review what changed
git add arch/ && git commit -m "config: update ..."
```

Then next time you run `arch-setup-i3.sh` on any machine, those changes are
deployed with everything else.

## Adding a New Config

1.  Create a folder under `arch/`, e.g. `arch/alacritty`.
2.  Add it to the `CONFIG_MAP` array in `scripts/config-map.sh`:
    ```bash
    [alacritty]="alacritty"
    ```
    Use a different value on the right if the config directory name differs from
    the folder name (e.g. `[neovim]="nvim"`).

## Recommendations for Maintenance

- **Updating packages**: Keep `pkglist/pacman.txt` and `pkglist/aur.txt` updated with your latest changes.
- **Portability**: Paths inside the configs should use `~`/`$HOME`, never a hardcoded home directory (e.g. `/home/zak`).
- **Portability**: For managing more complex or multi-OS environments, consider migrating to `GNU Stow` or `chezmoi`.
