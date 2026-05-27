# WSL2 Debian Setup

Run inside your Debian WSL instance.

---

## Quick start

```bash
./run_all.sh
```

Or run individually:

| # | Script | What it does |
|---|---|---|
| 1 | `1_packages.sh` | System update, install packages (tmux, curl, git, etc.), set timezone |
| 2 | `2_nerdfonts.sh` | Install FiraCode Nerd Font for WSL terminal apps (nvim, tmux) |
| 3 | `3_lazyvim.sh` | Neovim + LazyVim + Python LSP |
| 4 | `4_starship.sh` | Starship prompt + custom `starship.toml` preset |
| 5 | `5_zoxide.sh` | `z` — smarter `cd` |
| 6 | `6_tmux.sh` | tmux config + TPM plugins (yank, resurrect, continuum) |
| 7 | `7_bash.sh` | Bash aliases, history tweaks, env vars |

---

## After setup

```bash
source ~/.bashrc
tmux
# Inside tmux: prefix + I  (capital i) to install TPM plugins
nvim                     # Plugins auto-install on first launch
```

Windows Terminal font is set automatically by `pwsh\2_install_debian.ps1`.
