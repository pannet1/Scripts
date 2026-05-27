# Yazi — Terminal File Manager

## Install (if not already)
```bash
sudo apt install yazi         # Debian trixie+
# OR download binary:
curl -sL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip" -o /tmp/y.zip
unzip /tmp/y.zip -d /tmp/y && sudo cp /tmp/y/yazi-x86_64-unknown-linux-gnu/{yazi,ya} /usr/local/bin/
```

## Previews on WSL2
| File type | Works? | Notes |
|:---|---:|:---|
| Text / Code | ✅ syntax highlighted | needs `bat` (`sudo apt install bat`) |
| PDF | ✅ text content | needs `poppler-utils` (already installed) |
| JSON/YAML/TOML | ✅ formatted | built-in |
| CSV/TSV | ✅ column view | built-in |
| Archives (zip/tar) | ✅ file listing | built-in |
| Images | ⬜ ASCII art | Chafa fallback via ConPTY |

## Keybindings (daily use)
```
yazi              → open in current directory
j/k or ↑/↓       → navigate
h                → parent directory
l or →           → enter directory / open file
V                → visual mode (start bulk select)
Space            → toggle file selection
c                → copy selected
p                → paste
d                → delete selected
q                → quit
/                → fuzzy search
g + s            → SSH/SFTP: type user@host → browse remote
g + h            → back to local filesystem
t                → new tab
Tab              → switch tabs
~                → go to home directory
:                → command mode (type `:help` for all)

On any file:
Enter            → open with default opener (nvim for text)
F1               → full keybinding cheat sheet
```

## SFTP (remote browsing)
```
g s                     → connect to remote
→ type: user@host       → authenticated via SSH key
→ browse remote files   → copy/paste works cross-panel
g h                     → disconnect and back to local
```

## Dotfiles
Config: `~/.config/yazi/yazi.toml` (symlinked from dotfiles repo)
