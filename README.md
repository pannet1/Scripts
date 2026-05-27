# Scripts

Dotfiles and provision scripts managed via GNU Stow.

## Packages

| Package   | OS                   |
|-----------|----------------------|
| `common/` | Shared (all OS)      |
| `wsl2/`   | WSL2 Debian          |
| `eos/`    | EndeavourOS          |
| `nix/`    | NixOS                |

## Install

```bash
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

## Secrets

Encrypted with `git-crypt` in `~/programs/shell/github.com/pannet1/secrets/`.
