# Scripts

Dotfiles and provision scripts managed via GNU Stow.

## Packages

| Package   | OS                   |
|-----------|----------------------|
| `common/` | Shared (all OS)      |
| `debian/` | Debian desktop       |
| `wsl2/`   | WSL2 Debian          |
| `eos/`    | EndeavourOS          |
| `nix/`    | NixOS                |

## Install

```bash
# Debian desktop (netinstall → internet → curl)
bash <(curl -fsSL https://raw.githubusercontent.com/pannet1/Scripts/main/install-debian.sh)

# WSL2 Debian
./install-wsl2.sh

# EndeavourOS
./install-eos.sh
```

## Post-install

```bash
tmux          # then prefix + I for plugins
nvim          # plugins auto-install on first launch
```

## Qtile wallpapers & themes

Each qtile (re)start picks a random image from `~/.config/qtile/wallpapers/` and
regenerates the color scheme from it via [wallust](https://codeberg.org/explosion-mental/wallust).
Drop images (jpg/png/webp/...) into `~/.config/qtile/wallpapers/`; `mod+w` re-rolls
wallpaper + theme, `mod+ctrl+r` restarts qtile.

- `common/.config/wallust/wallust.toml` — wallust palette config
- `common/.config/wallust/templates/qtile-colors.json` — maps palette → qtile colors.json
- Generated scheme is written to `~/.cache/wallust/qtile-colors.json` (committed `colors.json` is the fallback)

## Secrets

Encrypted with `git-crypt` in `~/programs/shell/github.com/pannet1/secrets/`.
