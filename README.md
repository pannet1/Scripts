# Scripts Directory

My personal scripts organized by purpose.

## Directory Structure

| Directory | Purpose |
|-----------|---------|
| `ai/` | AI experiments and prompts |
| `alpine/` | Laptop hardware tests from Alpine bootable USB |
| `backup/` | Rsync backup scripts for cloud storage sync |
| `client/` | Scripts meant for local machines (not VPS) |
| `conf/` | Legacy configuration files |
| `exclude_lists/` | Rsync exclude patterns for cloud sync |
| `mxlinux/` | MX Linux specific scripts |
| `nix/` | Nix/NixOS related scripts |
| `pwsh/` | PowerShell scripts |
| `server/` | Server/VPS related scripts |
| `wsl2/` | WSL2 specific scripts |
| `xsh/` | Xonsh shell scripts |

## Details

### backup/
- `rsyncing.bash` - Main rsync backup script
- `rsyncronjobs` - Cron jobs for backup scheduling
- `exclude_lists/` - Patterns to exclude from sync

### conf/
- Legacy config files (httpd.conf, php.ini)
- Probably not in use

### wsl2/
- WSL2 specific setup and utilities

## Usage

Scripts are typically copied to and run from their target environment:
- `server/` scripts → copied to VPS
- `client/` scripts → run locally on Windows/Linux desktop
- `wsl2/` scripts → run in WSL2 environment